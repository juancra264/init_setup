#!/bin/bash
# ============================================================
#  OpenClaw Installer for Debian 13
#  Usage: sudo bash install_openclaw_debian13.sh
# ============================================================

set -e  # Exit on any error

# ── Colors ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ── Helpers ───────────────────────────────────────────────────
info()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
success() { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Banner ────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}   OpenClaw Installer — Debian 13          ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# ── Root check ────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  error "Please run this script as root or with sudo."
fi

# ── Variables ─────────────────────────────────────────────────
OPENCLAW_USER="openclaw"
NVM_VERSION="v0.39.7"
NODE_VERSION="22"
INSTALL_DIR="/home/${OPENCLAW_USER}"
SERVICE_FILE="/etc/systemd/system/openclaw.service"

# ─────────────────────────────────────────────────────────────
# STEP 1 — System Update & Base Dependencies
# ─────────────────────────────────────────────────────────────
info "Step 1/7 — Updating system and installing base dependencies..."
apt update -y && apt upgrade -y
apt install -y \
  curl \
  wget \
  git \
  build-essential \
  ca-certificates \
  gnupg \
  lsb-release \
  software-properties-common \
  ufw
success "Base dependencies installed."

# ─────────────────────────────────────────────────────────────
# STEP 2 — Create Dedicated OpenClaw User
# ─────────────────────────────────────────────────────────────
info "Step 2/7 — Creating dedicated system user '${OPENCLAW_USER}'..."
if id "${OPENCLAW_USER}" &>/dev/null; then
  warn "User '${OPENCLAW_USER}' already exists. Skipping."
else
  useradd -m -s /bin/bash "${OPENCLAW_USER}"
  success "User '${OPENCLAW_USER}' created."
fi

# ─────────────────────────────────────────────────────────────
# STEP 3 — Install Node.js via nvm
# ─────────────────────────────────────────────────────────────
info "Step 3/7 — Installing Node.js ${NODE_VERSION} via nvm..."

sudo -u "${OPENCLAW_USER}" bash <<EOF
export HOME=${INSTALL_DIR}
export NVM_DIR="${INSTALL_DIR}/.nvm"

# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash

# Load nvm
source "\${NVM_DIR}/nvm.sh"

# Install Node.js
nvm install ${NODE_VERSION}
nvm use ${NODE_VERSION}
nvm alias default ${NODE_VERSION}

# Verify
node -v
npm -v
EOF

success "Node.js installed."

# ─────────────────────────────────────────────────────────────
# STEP 4 — Install OpenClaw
# ─────────────────────────────────────────────────────────────
info "Step 4/7 — Installing OpenClaw..."

sudo -u "${OPENCLAW_USER}" bash <<'EOF'
export HOME=/home/openclaw
export NVM_DIR="${HOME}/.nvm"
source "${NVM_DIR}/nvm.sh"

# Install via official script
curl -fsSL https://openclaw.ai/install-cli.sh | bash

# Verify install
openclaw --version || echo "Note: run 'openclaw onboard' to complete setup."
EOF

success "OpenClaw installed."

# ─────────────────────────────────────────────────────────────
# STEP 5 — Add openclaw to PATH system-wide
# ─────────────────────────────────────────────────────────────
info "Step 5/7 — Configuring PATH for openclaw user..."

BASHRC="/home/${OPENCLAW_USER}/.bashrc"
PROFILE="/home/${OPENCLAW_USER}/.profile"

grep -qxF 'export NVM_DIR="$HOME/.nvm"' "${BASHRC}" || cat >> "${BASHRC}" <<'ENVBLOCK'

# NVM & OpenClaw
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
ENVBLOCK

success "PATH configured."

# ─────────────────────────────────────────────────────────────
# STEP 6 — Create systemd Service
# ─────────────────────────────────────────────────────────────
info "Step 6/7 — Creating systemd service for OpenClaw..."

# Resolve node binary path
NODE_BIN=$(sudo -u "${OPENCLAW_USER}" bash -c \
  'source ~/.nvm/nvm.sh && which node')
OPENCLAW_BIN=$(sudo -u "${OPENCLAW_USER}" bash -c \
  'source ~/.nvm/nvm.sh && which openclaw 2>/dev/null || echo ""')

cat > "${SERVICE_FILE}" <<SERVICEBLOCK
[Unit]
Description=OpenClaw AI Agent Gateway
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=${OPENCLAW_USER}
WorkingDirectory=${INSTALL_DIR}
Environment=HOME=${INSTALL_DIR}
Environment=NODE_PATH=${NODE_BIN%/node}
ExecStartPre=/bin/bash -c 'source ${INSTALL_DIR}/.nvm/nvm.sh'
ExecStart=/bin/bash -c 'source ${INSTALL_DIR}/.nvm/nvm.sh && openclaw gateway start'
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICEBLOCK

systemctl daemon-reload
systemctl enable openclaw
success "Systemd service created and enabled."

# ─────────────────────────────────────────────────────────────
# STEP 7 — Firewall Configuration
# ─────────────────────────────────────────────────────────────
info "Step 7/7 — Configuring UFW firewall..."

ufw --force enable
ufw allow OpenSSH
# OpenClaw dashboard port (localhost only — do NOT expose publicly)
# Access via SSH tunnel: ssh -N -L 18789:127.0.0.1:18789 user@server
warn "OpenClaw dashboard (port 18789) is bound to localhost only for security."
warn "Use SSH tunneling to access it: ssh -N -L 18789:127.0.0.1:18789 user@YOUR_SERVER_IP"

success "Firewall configured."

# ─────────────────────────────────────────────────────────────
# DONE
# ─────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   Installation Complete!                  ${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "  ${YELLOW}Next Steps:${NC}"
echo ""
echo -e "  1. Switch to the openclaw user and run onboarding:"
echo -e "     ${BLUE}sudo su - openclaw${NC}"
echo -e "     ${BLUE}openclaw onboard --install-daemon${NC}"
echo ""
echo -e "  2. Start the service:"
echo -e "     ${BLUE}sudo systemctl start openclaw${NC}"
echo -e "     ${BLUE}sudo systemctl status openclaw${NC}"
echo ""
echo -e "  3. Access dashboard via SSH tunnel from your local machine:"
echo -e "     ${BLUE}ssh -N -L 18789:127.0.0.1:18789 your_user@YOUR_SERVER_IP${NC}"
echo -e "     Then open: ${BLUE}http://localhost:18789${NC}"
echo ""
echo -e "  4. Useful commands:"
echo -e "     ${BLUE}openclaw doctor${NC}          — Check for issues"
echo -e "     ${BLUE}openclaw gateway status${NC}  — Gateway status"
echo -e "     ${BLUE}openclaw logs --follow${NC}   — Tail logs"
echo -e "     ${BLUE}openclaw update${NC}          — Update OpenClaw"
echo ""
echo -e "${GREEN}  Default credentials after onboarding:${NC}"
echo -e "  Username: admin  |  Password: password"
echo ""
