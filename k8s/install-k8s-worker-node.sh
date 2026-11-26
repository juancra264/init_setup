#!/usr/bin/env bash
# ==============================================================================
# Kubernetes Worker Node Automated Installer
# Target OS: Debian 13 (Trixie) - Minimal Server Edition
# ==============================================================================
set -euo pipefail

# --- Default Configuration Variables ---
K8S_VERSION="${K8S_VERSION:-1.31}"          # Target Kubernetes minor version (matches control plane)
JOIN_COMMAND="${JOIN_COMMAND:-}"            # Full join command (e.g., 'kubeadm join 10.0.0.10:6443 --token ...')
CONTROL_PLANE_ENDPOINT="${CONTROL_PLANE_ENDPOINT:-}" # Control plane IP/Host:Port
DISCOVERY_TOKEN="${DISCOVERY_TOKEN:-}"      # Bootstrap token
CA_CERT_HASH="${CA_CERT_HASH:-}"            # Discovery token CA cert hash (sha256:...)
NODE_NAME="${NODE_NAME:-}"                  # Custom node name override (optional)

# --- Terminal Styling ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

print_banner() {
    echo -e "${BLUE}${BOLD}"
    cat <<'EOF'
  _  ______   _____   __          __        _             
 | |/ /___ \ / ____|  \ \        / /       | |            
 | ' /  __) | (___     \ \  /\  / /__  _ __| | _____ _ __ 
 |  <  |__ < \___ \     \ \/  \/ / _ \| '__| |/ / _ \ '__|
 | . \ ___) |____) |     \  /\  / (_) | |  |   <  __/ |   
 |_|\_\____/|_____/       \/  \/ \___/|_|  |_|\_\___|_|   
 Worker Node Installer for Debian 13 (Minimal)
EOF
    echo -e "${NC}"
}

usage() {
    cat <<EOF
Usage: sudo ./install-k8s-worker-node.sh [OPTIONS]

Options:
  -v, --version <version>       Kubernetes version branch (default: 1.31)
  -j, --join "<command>"        Full kubeadm join command copied from control plane
  -e, --endpoint <host:port>    Control plane endpoint (e.g. 192.168.1.50:6443)
  -t, --token <token>           Bootstrap join token
  --hash <sha256:hash>          Discovery CA cert hash (format: sha256:<64-hex>)
  --name <custom-node-name>     Optional node name override
  -h, --help                    Show this help message

Environment variables can also be used:
  K8S_VERSION, JOIN_COMMAND, CONTROL_PLANE_ENDPOINT, DISCOVERY_TOKEN, CA_CERT_HASH, NODE_NAME

Examples:
  # 1. Prepare node only (join manually later):
  sudo ./install-k8s-worker-node.sh

  # 2. Automatically join using the complete command string from control plane:
  sudo ./install-k8s-worker-node.sh --join "kubeadm join 192.168.1.100:6443 --token abcdef.0123456789abcdef --discovery-token-ca-cert-hash sha256:1234...abcd"

  # 3. Join specifying individual parameters:
  sudo ./install-k8s-worker-node.sh --endpoint 192.168.1.100:6443 --token abcdef.0123456789abcdef --hash sha256:1234...abcd
EOF
    exit 0
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--version)
                K8S_VERSION="$2"
                shift 2
                ;;
            -j|--join)
                JOIN_COMMAND="$2"
                shift 2
                ;;
            -e|--endpoint)
                CONTROL_PLANE_ENDPOINT="$2"
                shift 2
                ;;
            -t|--token)
                DISCOVERY_TOKEN="$2"
                shift 2
                ;;
            --hash)
                CA_CERT_HASH="$2"
                shift 2
                ;;
            --name)
                NODE_NAME="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
}

# --- Step 1: Pre-flight Validations ---
preflight_checks() {
    log_info "Running pre-flight checks..."

    # Check root privileges
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (or with sudo)."
        exit 1
    fi

    # Detect OS
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        if [[ "${ID:-}" != "debian" ]]; then
            log_warn "Current OS is '${ID:-unknown}'. This script is optimized for Debian 13 (Trixie)."
        else
            log_info "Detected OS: ${PRETTY_NAME:-Debian}"
        fi
    else
        log_warn "Could not read /etc/os-release."
    fi

    local cpu_cores
    cpu_cores=$(nproc)
    log_info "CPU Cores: $cpu_cores"

    local total_mem_mb
    total_mem_mb=$(free -m | awk '/^Mem:/{print $2}')
    log_info "Memory: ${total_mem_mb}MB"
    log_info "Target Kubernetes version: v${K8S_VERSION}"
}

# --- Step 2: System Update & Essential Minimal Tools ---
install_prerequisites() {
    log_info "Updating package lists and installing core dependencies for Debian Minimal..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y

    # Debian minimal often lacks these essential networking and HTTPS packages
    apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        iproute2 \
        iptables \
        socat \
        conntrack \
        procps \
        ethtool \
        ebtables \
        tar

    log_success "Prerequisite packages installed."
}

# --- Step 3: Swap Management ---
disable_swap() {
    log_info "Disabling swap (required by kubelet)..."
    swapoff -a || true

    # Comment out swap entries in /etc/fstab
    if grep -q "swap" /etc/fstab; then
        sed -i.bak -r '/\sswap\s/s/^#?/#/' /etc/fstab
        log_info "Commented out swap entries in /etc/fstab (backup at /etc/fstab.bak)."
    fi

    # Mask systemd swap unit if present
    systemctl mask swap.target >/dev/null 2>&1 || true
    log_success "Swap disabled permanently."
}

# --- Step 4: Kernel Modules and Sysctl for Container Networking ---
configure_kernel() {
    log_info "Configuring Linux kernel modules and sysctl parameters..."

    cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

    modprobe overlay
    modprobe br_netfilter

    cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

    sysctl --system >/dev/null
    log_success "Kernel modules (overlay, br_netfilter) and sysctl network params applied."
}

# --- Step 5: Container Runtime (containerd) Setup ---
install_containerd() {
    log_info "Setting up containerd container runtime..."

    if ! command -v containerd >/dev/null 2>&1; then
        apt-get install -y containerd
    fi

    mkdir -p /etc/containerd
    
    # Generate default config and ensure systemd cgroup driver is enabled
    containerd config default > /etc/containerd/config.toml

    # 1. Enable SystemdCgroup
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

    # 2. Fix Debian-specific issue where CRI plugin might be listed in disabled_plugins
    sed -i 's/disabled_plugins = \["cri"\]//g' /etc/containerd/config.toml

    systemctl daemon-reload
    systemctl enable containerd
    systemctl restart containerd

    if systemctl is-active --quiet containerd; then
        log_success "containerd runtime active with SystemdCgroup=true."
    else
        log_error "containerd service failed to start. Check 'systemctl status containerd'."
        exit 1
    fi
}

# --- Step 6: Kubernetes APT Repository & Packages ---
install_kubernetes_packages() {
    log_info "Configuring official Kubernetes repository (pkgs.k8s.io v${K8S_VERSION})..."

    install -m 0755 -d /etc/apt/keyrings

    local keyring_path="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
    curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/Release.key" | \
        gpg --dearmor -o "$keyring_path" --yes

    cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb [signed-by=$keyring_path] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/ /
EOF

    apt-get update -y

    log_info "Installing kubelet, kubeadm, and kubectl..."
    apt-get install -y kubelet kubeadm kubectl

    apt-mark hold kubelet kubeadm kubectl

    systemctl enable kubelet
    log_success "Kubernetes packages installed and held at current version."
}

# --- Step 7: Join Kubernetes Cluster ---
join_cluster() {
    local executed_join=false

    # Option A: Full join command passed directly
    if [[ -n "$JOIN_COMMAND" ]]; then
        log_info "Executing provided join command..."
        # If the command starts with 'kubeadm join' or 'sudo kubeadm join', run it
        # Strip leading sudo if present
        local clean_cmd="${JOIN_COMMAND#sudo }"
        
        if [[ -n "$NODE_NAME" ]]; then
            clean_cmd="${clean_cmd} --node-name ${NODE_NAME}"
        fi

        eval "$clean_cmd"
        executed_join=true

    # Option B: Join via individual parameters
    elif [[ -n "$CONTROL_PLANE_ENDPOINT" && -n "$DISCOVERY_TOKEN" && -n "$CA_CERT_HASH" ]]; then
        log_info "Executing kubeadm join with provided parameters..."
        local join_args=(
            kubeadm join "$CONTROL_PLANE_ENDPOINT"
            --token "$DISCOVERY_TOKEN"
            --discovery-token-ca-cert-hash "$CA_CERT_HASH"
        )
        if [[ -n "$NODE_NAME" ]]; then
            join_args+=(--node-name "$NODE_NAME")
        fi

        "${join_args[@]}"
        executed_join=true
    fi

    if [[ "$executed_join" == "true" ]]; then
        log_success "Node joined to the cluster successfully!"
    else
        log_warn "No join credentials provided. The node is fully prepared to join."
    fi
}

# --- Step 8: Summary ---
print_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}==============================================================================${NC}"
    echo -e "${GREEN}${BOLD}      Kubernetes Worker Node Setup Completed Successfully!                   ${NC}"
    echo -e "${GREEN}${BOLD}==============================================================================${NC}"
    echo ""
    if [[ -z "$JOIN_COMMAND" && ( -z "$CONTROL_PLANE_ENDPOINT" || -z "$DISCOVERY_TOKEN" || -z "$CA_CERT_HASH" ) ]]; then
        echo -e "${BOLD}Next Step: Join this node to the control plane:${NC}"
        echo ""
        echo "1. On your Control Plane node, generate the join command (if you don't have one):"
        echo -e "   ${CYAN}sudo kubeadm token create --print-join-command${NC}"
        echo ""
        echo "2. Run that command on this worker node:"
        echo -e "   ${CYAN}sudo kubeadm join <control-plane-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>${NC}"
        echo ""
    else
        echo -e "${BOLD}Worker node joined!${NC}"
        echo "You can verify this node on the Control Plane node by running:"
        echo -e "   ${CYAN}kubectl get nodes -o wide${NC}"
        echo ""
    fi
}

# --- Main Entry Point ---
main() {
    print_banner
    parse_arguments "$@"
    preflight_checks
    install_prerequisites
    disable_swap
    configure_kernel
    install_containerd
    install_kubernetes_packages
    join_cluster
    print_summary
}

main "$@"
