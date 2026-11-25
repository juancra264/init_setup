#!/usr/bin/env bash

# ==============================================================================
# Script: install_warpgate.sh
# Description: Install Warpgate bastion host (SSH, RDP, HTTP/HTTPS, VNC) on a
#              minimal Debian 13 LXC running under Proxmox VE.
# Usage:       sudo bash install_warpgate.sh
#
# Environment overrides:
#   WARPGATE_VERSION         Release tag (default: latest from GitHub)
#   WARPGATE_ADMIN_PASSWORD  Initial admin password (default: auto-generated)
#   WARPGATE_HTTP_PORT       Web UI / HTTP(S) proxy port (default: 8888)
#   WARPGATE_SSH_PORT        SSH proxy port (default: 2222)
#   WARPGATE_RDP_PORT        RDP proxy port (default: 3389)
#   WARPGATE_VNC_PORT        VNC proxy port (default: 5900)
#   WARPGATE_EXTERNAL_HOST   Optional external hostname/IP for links
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration (overridable via environment)
# ------------------------------------------------------------------------------
WARPGATE_VERSION="${WARPGATE_VERSION:-latest}"
WARPGATE_USER="warpgate"
WARPGATE_GROUP="warpgate"
WARPGATE_DATA_DIR="/var/lib/warpgate"
WARPGATE_CONFIG_DIR="/etc/warpgate"
WARPGATE_CONFIG_FILE="${WARPGATE_CONFIG_DIR}/warpgate.yaml"
WARPGATE_BIN_DIR="/usr/local/bin"
WARPGATE_BIN="${WARPGATE_BIN_DIR}/warpgate"
WARPGATE_SERVICE_FILE="/etc/systemd/system/warpgate.service"

WARPGATE_HTTP_PORT="${WARPGATE_HTTP_PORT:-8888}"
WARPGATE_SSH_PORT="${WARPGATE_SSH_PORT:-2222}"
WARPGATE_RDP_PORT="${WARPGATE_RDP_PORT:-3389}"
WARPGATE_VNC_PORT="${WARPGATE_VNC_PORT:-5900}"
WARPGATE_EXTERNAL_HOST="${WARPGATE_EXTERNAL_HOST:-}"
WARPGATE_ADMIN_PASSWORD="${WARPGATE_ADMIN_PASSWORD:-}"

# ------------------------------------------------------------------------------
# Colors / helpers
# ------------------------------------------------------------------------------
red=$(tput setaf 1 2>/dev/null || true)
green=$(tput setaf 2 2>/dev/null || true)
yellow=$(tput setaf 3 2>/dev/null || true)
blue=$(tput setaf 4 2>/dev/null || true)
reset=$(tput sgr0 2>/dev/null || true)

info() { printf '%s[info]%s %s\n' "${blue}" "${reset}" "$*"; }
ok()   { printf '%s[ ok ]%s %s\n' "${green}" "${reset}" "$*"; }
warn() { printf '%s[warn]%s %s\n' "${yellow}" "${reset}" "$*"; }
err()  { printf '%s[err ]%s %s\n' "${red}" "${reset}" "$*" >&2; }

# ------------------------------------------------------------------------------
# Require root
# ------------------------------------------------------------------------------
if [[ "${EUID}" -ne 0 ]]; then
  err "This script must be run as root (use sudo)."
  exit 1
fi

# ------------------------------------------------------------------------------
# Verify Debian
# ------------------------------------------------------------------------------
if [[ ! -f /etc/os-release ]]; then
  err "/etc/os-release not found. This script requires Debian."
  exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release

if [[ "${ID:-}" != "debian" ]] && [[ "${ID_LIKE:-}" != *"debian"* ]]; then
  err "Unsupported OS: ${ID:-unknown} (expected Debian)."
  exit 1
fi

info "Detected Debian ${VERSION_ID:-unknown} (${VERSION_CODENAME:-unknown})"

# ------------------------------------------------------------------------------
# Detect architecture
# ------------------------------------------------------------------------------
ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64)        WARPGATE_ARCH="x86_64-linux" ;;
  aarch64|arm64) WARPGATE_ARCH="aarch64-linux" ;;
  *) err "Unsupported architecture: ${ARCH}"; exit 1 ;;
esac
info "Architecture: ${ARCH} (${WARPGATE_ARCH})"

# ------------------------------------------------------------------------------
# Update system & install minimal runtime dependencies
# ------------------------------------------------------------------------------
info "Updating package lists and installing minimal dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  jq \
  openssl

# ------------------------------------------------------------------------------
# Resolve Warpgate release version
# ------------------------------------------------------------------------------
if [[ "${WARPGATE_VERSION}" == "latest" ]]; then
  info "Fetching latest Warpgate release tag from GitHub..."
  WARPGATE_TAG="$(
    curl -fsSL --retry 3 --connect-timeout 15 \
      "https://api.github.com/repos/warp-tech/warpgate/releases/latest" |
      jq -r '.tag_name // empty'
  )"
  if [[ -z "${WARPGATE_TAG}" ]]; then
    err "Failed to resolve latest Warpgate version from GitHub API."
    exit 1
  fi
else
  WARPGATE_TAG="v${WARPGATE_VERSION#v}"
fi
info "Target Warpgate release: ${WARPGATE_TAG}"

# ------------------------------------------------------------------------------
# Create dedicated unprivileged warpgate user
# ------------------------------------------------------------------------------
if ! id "${WARPGATE_USER}" &>/dev/null; then
  info "Creating system user ${WARPGATE_USER}..."
  useradd --system --create-home --home-dir "${WARPGATE_DATA_DIR}" --shell /usr/sbin/nologin "${WARPGATE_USER}"
else
  info "User ${WARPGATE_USER} already exists."
fi

# ------------------------------------------------------------------------------
# Download and install Warpgate binary
# ------------------------------------------------------------------------------
WARPGATE_RELEASE_URL="https://github.com/warp-tech/warpgate/releases/download/${WARPGATE_TAG}/warpgate-${WARPGATE_TAG}-${WARPGATE_ARCH}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

info "Downloading Warpgate ${WARPGATE_TAG}..."
if ! curl -fsSL --retry 3 --connect-timeout 15 -o "${TMP_DIR}/warpgate" "${WARPGATE_RELEASE_URL}"; then
  err "Failed to download Warpgate from ${WARPGATE_RELEASE_URL}"
  exit 1
fi

install -d -m 0755 "${WARPGATE_BIN_DIR}"
install -m 0755 "${TMP_DIR}/warpgate" "${WARPGATE_BIN}"
ok "Warpgate installed to ${WARPGATE_BIN} ($("${WARPGATE_BIN}" --version 2>/dev/null || echo "${WARPGATE_TAG}"))"

# ------------------------------------------------------------------------------
# Directory layout with correct ownership
# ------------------------------------------------------------------------------
install -d -o "${WARPGATE_USER}" -g "${WARPGATE_GROUP}" -m 0750 "${WARPGATE_DATA_DIR}"
install -d -o "${WARPGATE_USER}" -g "${WARPGATE_GROUP}" -m 0750 "${WARPGATE_CONFIG_DIR}"

# ------------------------------------------------------------------------------
# Unattended initial setup (idempotent)
# ------------------------------------------------------------------------------
GENERATED_PASSWORD=false
if [[ ! -f "${WARPGATE_CONFIG_FILE}" ]]; then
  if [[ -z "${WARPGATE_ADMIN_PASSWORD}" ]]; then
    WARPGATE_ADMIN_PASSWORD="$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)"
    GENERATED_PASSWORD=true
  fi

  info "Running Warpgate unattended setup..."
  SETUP_HELP="$("${WARPGATE_BIN}" unattended-setup --help 2>&1 || true)"

  SETUP_ARGS=(
    --config "${WARPGATE_CONFIG_FILE}"
    --data-path "${WARPGATE_DATA_DIR}"
    --http-port "${WARPGATE_HTTP_PORT}"
    --ssh-port "${WARPGATE_SSH_PORT}"
    --admin-password "${WARPGATE_ADMIN_PASSWORD}"
    --record-sessions
  )

  if grep -q -- '--rdp-port' <<<"${SETUP_HELP}"; then
    SETUP_ARGS+=(--rdp-port "${WARPGATE_RDP_PORT}")
  fi
  if grep -q -- '--vnc-port' <<<"${SETUP_HELP}"; then
    SETUP_ARGS+=(--vnc-port "${WARPGATE_VNC_PORT}")
  fi
  if [[ -n "${WARPGATE_EXTERNAL_HOST}" ]] && grep -q -- '--external-host' <<<"${SETUP_HELP}"; then
    SETUP_ARGS+=(--external-host "${WARPGATE_EXTERNAL_HOST}")
  fi

  su -s /bin/sh "${WARPGATE_USER}" -c \
    "$(printf '%q ' "${WARPGATE_BIN}" unattended-setup "${SETUP_ARGS[@]}")"

  # Ensure RDP listener block is present in config
  if ! grep -q '^rdp:' "${WARPGATE_CONFIG_FILE}"; then
    info "Enabling RDP listener on port ${WARPGATE_RDP_PORT} in ${WARPGATE_CONFIG_FILE}..."
    cat >>"${WARPGATE_CONFIG_FILE}" <<EOF

rdp:
  enable: true
  listen: "[::]:${WARPGATE_RDP_PORT}"
  certificate: ${WARPGATE_DATA_DIR}/tls.certificate.pem
  key: ${WARPGATE_DATA_DIR}/tls.key.pem
EOF
  fi

  # Ensure VNC listener block is present in config
  if ! grep -q '^vnc:' "${WARPGATE_CONFIG_FILE}"; then
    info "Enabling VNC listener on port ${WARPGATE_VNC_PORT} in ${WARPGATE_CONFIG_FILE}..."
    cat >>"${WARPGATE_CONFIG_FILE}" <<EOF

vnc:
  enable: true
  listen: "[::]:${WARPGATE_VNC_PORT}"
EOF
  fi

  chown "${WARPGATE_USER}:${WARPGATE_GROUP}" "${WARPGATE_CONFIG_FILE}"
  chmod 0640 "${WARPGATE_CONFIG_FILE}"
  ok "Warpgate configuration initialized at ${WARPGATE_CONFIG_FILE}"
else
  warn "Warpgate config already exists at ${WARPGATE_CONFIG_FILE}. Skipping unattended setup."
fi

# ------------------------------------------------------------------------------
# systemd service unit (hardened)
# ------------------------------------------------------------------------------
info "Writing hardened systemd unit to ${WARPGATE_SERVICE_FILE}..."
cat >"${WARPGATE_SERVICE_FILE}" <<EOF
[Unit]
Description=Warpgate Bastion Host (SSH / RDP / HTTP / VNC)
Documentation=https://github.com/warp-tech/warpgate
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=${WARPGATE_USER}
Group=${WARPGATE_GROUP}
WorkingDirectory=${WARPGATE_DATA_DIR}
ExecStart=${WARPGATE_BIN} --config ${WARPGATE_CONFIG_FILE} run
Restart=always
RestartSec=5

# Allow binding privileged ports (<1024) if configured (e.g. 443 or 22)
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=${WARPGATE_DATA_DIR} ${WARPGATE_CONFIG_DIR}
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
LockPersonality=true

StandardOutput=journal
StandardError=journal
SyslogIdentifier=warpgate

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now warpgate.service

ok "Warpgate systemd service enabled and started."

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || echo '<LXC_IP>')"
echo
ok "Warpgate installation complete."
echo
echo "  Binary:      ${WARPGATE_BIN}"
echo "  Config:      ${WARPGATE_CONFIG_FILE}"
echo "  Data dir:    ${WARPGATE_DATA_DIR}"
echo "  Service:     systemctl status warpgate"
echo "  Logs:        journalctl -u warpgate -f"
echo "  Version:     ${WARPGATE_TAG}"
echo
echo "  Bastion Listeners:"
echo "    Web UI / HTTP(S): https://${HOST_IP}:${WARPGATE_HTTP_PORT}"
echo "    SSH Proxy:        ${HOST_IP}:${WARPGATE_SSH_PORT}"
echo "    RDP Proxy:        ${HOST_IP}:${WARPGATE_RDP_PORT}"
echo "    VNC Proxy:        ${HOST_IP}:${WARPGATE_VNC_PORT}"
echo
if [[ "${GENERATED_PASSWORD}" == "true" ]]; then
  echo "  Admin User:  admin"
  echo "  Admin Pass:  ${WARPGATE_ADMIN_PASSWORD}"
  echo "  (Save this password now; it will not be shown again.)"
  echo
fi
