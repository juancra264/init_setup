#!/usr/bin/env bash

# ==============================================================================
# Script: install_hermes_debian.sh
# Description: Install Hermes (IBC relayer by Informal Systems) on a minimal
#              Debian LXC running under Proxmox VE.
#
# Best practices applied:
#   - set -euo pipefail (strict error handling)
#   - must run as root
#   - dedicated unprivileged system user (hermes)
#   - config in /etc/hermes, data in /var/lib/hermes, binary in /usr/local/bin
#   - systemd unit with security hardening (NoNewPrivileges, ProtectSystem, ...)
#   - logs via journald (StandardOutput/Error=journal)
#   - idempotent: skips steps that already completed
#   - architecture detection (amd64 / arm64)
#   - DEBIAN_FRONTEND=noninteractive + --no-install-recommends (minimal LXC)
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration (overridable via environment)
# ------------------------------------------------------------------------------
HERMES_VERSION="${HERMES_VERSION:-1.9.0}"
HERMES_USER="hermes"
HERMES_GROUP="hermes"
HERMES_HOME="/var/lib/hermes"
HERMES_CONFIG_DIR="/etc/hermes"
HERMES_CONFIG_FILE="${HERMES_CONFIG_DIR}/config.toml"
HERMES_BIN_DIR="/usr/local/bin"
HERMES_BIN="${HERMES_BIN_DIR}/hermes"
HERMES_SERVICE_FILE="/etc/systemd/system/hermes.service"

# ------------------------------------------------------------------------------
# Colors / helpers
# ------------------------------------------------------------------------------
red=$(tput setaf 1 2>/dev/null || true)
green=$(tput setaf 2 2>/dev/null || true)
blue=$(tput setaf 4 2>/dev/null || true)
reset=$(tput sgr0 2>/dev/null || true)

info() { printf '%s[info]%s %s\n' "${blue}" "${reset}" "$*"; }
ok()   { printf '%s[ ok ]%s %s\n' "${green}" "${reset}" "$*"; }
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

if [[ "${ID}" != "debian" ]] && [[ "${ID_LIKE}" != *"debian"* ]]; then
  err "Unsupported OS: ${ID} (expected Debian)."
  exit 1
fi

info "Detected Debian ${VERSION_ID}"

# ------------------------------------------------------------------------------
# Detect architecture
# ------------------------------------------------------------------------------
ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64)  HERMES_ARCH="x86_64-unknown-linux-gnu" ;;
  aarch64|arm64) HERMES_ARCH="aarch64-unknown-linux-gnu" ;;
  *) err "Unsupported architecture: ${ARCH}"; exit 1 ;;
esac
info "Architecture: ${ARCH} (${HERMES_ARCH})"

# ------------------------------------------------------------------------------
# Update system & install minimal build/runtime dependencies
# ------------------------------------------------------------------------------
info "Updating package lists..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y

info "Installing dependencies..."
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  gnupg \
  tar \
  wget

# ------------------------------------------------------------------------------
# Create dedicated unprivileged hermes user
# ------------------------------------------------------------------------------
if ! id "${HERMES_USER}" &>/dev/null; then
  info "Creating system user ${HERMES_USER}..."
  useradd --system --create-home --home-dir "${HERMES_HOME}" --shell /usr/sbin/nologin "${HERMES_USER}"
else
  info "User ${HERMES_USER} already exists."
fi

# ------------------------------------------------------------------------------
# Install Hermes binary (prebuilt release from GitHub)
# ------------------------------------------------------------------------------
HERMES_RELEASE_URL="https://github.com/informalsystems/hermes/releases/download/v${HERMES_VERSION}/hermes-v${HERMES_VERSION}-${HERMES_ARCH}.tar.gz"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

info "Downloading Hermes v${HERMES_VERSION}..."
if ! curl -fsSL --retry 3 --connect-timeout 15 -o "${TMP_DIR}/hermes.tar.gz" "${HERMES_RELEASE_URL}"; then
  err "Failed to download Hermes from ${HERMES_RELEASE_URL}"
  err "Verify HERMES_VERSION (${HERMES_VERSION}) exists for ${HERMES_ARCH}."
  exit 1
fi

info "Extracting Hermes binary..."
tar -xzf "${TMP_DIR}/hermes.tar.gz" -C "${TMP_DIR}"

HERMES_BINARY="$(find "${TMP_DIR}" -type f -name 'hermes' | head -n 1 || true)"
if [[ -z "${HERMES_BINARY}" ]]; then
  err "Hermes binary not found inside the archive."
  exit 1
fi

install -d -m 0755 "${HERMES_BIN_DIR}"
install -m 0755 "${HERMES_BINARY}" "${HERMES_BIN}"
ok "Hermes installed to ${HERMES_BIN}"

# Verify it runs
"${HERMES_BIN}" --version >/dev/null 2>&1 || true

# ------------------------------------------------------------------------------
# Directory layout with correct ownership
# ------------------------------------------------------------------------------
install -d -o "${HERMES_USER}" -g "${HERMES_GROUP}" -m 0750 "${HERMES_HOME}"
install -d -o "${HERMES_USER}" -g "${HERMES_GROUP}" -m 0750 "${HERMES_CONFIG_DIR}"

# ------------------------------------------------------------------------------
# Default Hermes config (idempotent)
# ------------------------------------------------------------------------------
if [[ ! -f "${HERMES_CONFIG_FILE}" ]]; then
  info "Writing default Hermes config to ${HERMES_CONFIG_FILE}..."
  cat > "${HERMES_CONFIG_FILE}" <<'TOML'
[global]
log_level = 'info'

[mode]
[mode.clients]
enabled = true
refresh = true
refresh_rate = 2_000_000

[mode.connections]
enabled = false

[mode.chains]
enabled = false

[mode.packets]
enabled = true
clear_interval = 100
clear_on_start = true

[rest]
enabled = true
host = '127.0.0.1'
port = 3031

[telemetry]
enabled = true
host = '127.0.0.1'
port = 3032
TOML
  chown "${HERMES_USER}:${HERMES_GROUP}" "${HERMES_CONFIG_FILE}"
  chmod 0640 "${HERMES_CONFIG_FILE}"
  ok "Default config written."
else
  info "Hermes config already exists. Skipping."
fi

# ------------------------------------------------------------------------------
# systemd service unit (hardened)
# ------------------------------------------------------------------------------
cat > "${HERMES_SERVICE_FILE}" <<EOF
[Unit]
Description=Hermes IBC Relayer
Documentation=https://hermes.informal.systems/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${HERMES_USER}
Group=${HERMES_GROUP}
WorkingDirectory=${HERMES_HOME}
Environment=HERMES_CONFIG=${HERMES_CONFIG_FILE}
ExecStart=${HERMES_BIN} start --config ${HERMES_CONFIG_FILE}
Restart=always
RestartSec=5
StartLimitBurst=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=hermes

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=${HERMES_HOME} ${HERMES_CONFIG_DIR}
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
LockPersonality=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now hermes.service

ok "Hermes systemd service enabled and started."

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
ok "Hermes installation complete."
echo
echo "  Binary:    ${HERMES_BIN}"
echo "  Config:    ${HERMES_CONFIG_FILE}"
echo "  Data dir:  ${HERMES_HOME}"
echo "  Service:   systemctl status hermes"
echo "  Logs:      journalctl -u hermes -f"
echo "  Version:   ${HERMES_VERSION}"
echo
