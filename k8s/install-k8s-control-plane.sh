#!/usr/bin/env bash
# ==============================================================================
# Kubernetes Control Plane Node Automated Installer
# Target OS: Debian 13 (Trixie) - Minimal Server Edition
# ==============================================================================
set -euo pipefail

# --- Default Configuration Variables ---
K8S_VERSION="${K8S_VERSION:-1.31}"          # Target Kubernetes minor version (e.g., 1.30, 1.31, 1.32)
POD_CIDR="${POD_CIDR:-10.244.0.0/16}"       # Pod network CIDR (Default matches Flannel; use 192.168.0.0/16 for Calico)
CNI_PLUGIN="${CNI_PLUGIN:-flannel}"         # CNI plugin to install: flannel | calico | none
SINGLE_NODE="${SINGLE_NODE:-false}"         # Untaint control plane to allow scheduling workloads on it
CONTROL_PLANE_IP="${CONTROL_PLANE_IP:-}"    # IP address for API server to advertise (auto-detected if empty)
SKIP_INIT="${SKIP_INIT:-false}"             # If true, prepare node & packages only, skip `kubeadm init`

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
  _  ______   _____   _____           _             _ 
 | |/ /___ \ / ____| / ____|         | |           | |
 | ' /  __) | (___  | |     ___  _ __| |_ _ __ ___ | |
 |  <  |__ < \___ \ | |    / _ \| '__| __| '__/ _ \| |
 | . \ ___) |____) || |___| (_) | |  | |_| | | (_) | |
 |_|\_\____/|_____/  \_____\___/|_|   \__|_|  \___/|_|
 Control Plane Node Installer for Debian 13 (Minimal)
EOF
    echo -e "${NC}"
}

usage() {
    cat <<EOF
Usage: sudo ./install-k8s-control-plane.sh [OPTIONS]

Options:
  -v, --version <version>       Kubernetes version branch (default: 1.31)
  -p, --pod-cidr <cidr>         Pod network CIDR (default: 10.244.0.0/16)
  -c, --cni <flannel|calico|none> CNI network plugin to install (default: flannel)
  -i, --ip <ip-address>         API server advertise IP (default: auto-detected primary IP)
  -s, --single-node             Remove control-plane taint to allow running pods on master
  -n, --no-init                 Install dependencies and tools only; do not run kubeadm init
  -h, --help                    Show this help message

Environment variables can also be used:
  K8S_VERSION, POD_CIDR, CNI_PLUGIN, SINGLE_NODE, CONTROL_PLANE_IP, SKIP_INIT

Examples:
  sudo ./install-k8s-control-plane.sh
  sudo ./install-k8s-control-plane.sh --single-node --cni flannel
  sudo ./install-k8s-control-plane.sh --version 1.31 --cni calico --pod-cidr 192.168.0.0/16
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
            -p|--pod-cidr)
                POD_CIDR="$2"
                shift 2
                ;;
            -c|--cni)
                CNI_PLUGIN="$2"
                shift 2
                ;;
            -i|--ip)
                CONTROL_PLANE_IP="$2"
                shift 2
                ;;
            -s|--single-node)
                SINGLE_NODE="true"
                shift 1
                ;;
            -n|--no-init)
                SKIP_INIT="true"
                shift 1
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

    # Hardware resource checks
    local cpu_cores
    cpu_cores=$(nproc)
    if [[ "$cpu_cores" -lt 2 ]]; then
        log_warn "Found $cpu_cores CPU core(s). Kubernetes control plane requires at least 2 cores for stability."
    else
        log_info "CPU Cores: $cpu_cores (OK)"
    fi

    local total_mem_mb
    total_mem_mb=$(free -m | awk '/^Mem:/{print $2}')
    if [[ "$total_mem_mb" -lt 1700 ]]; then
        log_warn "Total memory is ${total_mem_mb}MB. Kubernetes control plane recommends at least 2048MB (2GB)."
    else
        log_info "Memory: ${total_mem_mb}MB (OK)"
    fi

    # Determine Control Plane IP
    if [[ -z "$CONTROL_PLANE_IP" ]]; then
        CONTROL_PLANE_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}' || true)
        if [[ -z "$CONTROL_PLANE_IP" ]]; then
            CONTROL_PLANE_IP=$(hostname -I | awk '{print $1}')
        fi
    fi
    log_info "Control Plane IP: $CONTROL_PLANE_IP"
    log_info "Kubernetes target version: v${K8S_VERSION}"
    log_info "Pod Network CIDR: ${POD_CIDR}"
    log_info "CNI Plugin: ${CNI_PLUGIN}"
    log_info "Single-node cluster mode: ${SINGLE_NODE}"
}

# --- Step 2: System Update & Essential Minimal Tools ---
install_prerequisites() {
    log_info "Updating package lists and installing core dependencies for Debian Minimal..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y

    # Debian minimal often lacks these essential tools for networking and HTTPS repos
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
        log_info "Commented out swap entries in /etc/fstab (backup created at /etc/fstab.bak)."
    fi

    # Mask systemd swap unit if present
    systemctl mask swap.target >/dev/null 2>&1 || true
    log_success "Swap disabled permanently."
}

# --- Step 4: Kernel Modules and Sysctl for Container Networking ---
configure_kernel() {
    log_info "Configuring Linux kernel modules and sysctl parameters..."

    # Kernel modules required for bridging and container overlays
    cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

    modprobe overlay
    modprobe br_netfilter

    # Sysctl network parameters
    cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

    sysctl --system >/dev/null
    log_success "Kernel modules (overlay, br_netfilter) and sysctl params applied."
}

# --- Step 5: Container Runtime (containerd) Setup ---
install_containerd() {
    log_info "Setting up containerd container runtime..."

    # Check if containerd is already installed, otherwise install it
    if ! command -v containerd >/dev/null 2>&1; then
        apt-get install -y containerd
    fi

    # Prepare containerd configuration directory
    mkdir -p /etc/containerd
    
    # Generate default config and ensure systemd cgroup driver is enabled
    containerd config default > /etc/containerd/config.toml

    # 1. Enable SystemdCgroup
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

    # 2. Fix Debian-specific issue where CRI plugin might be listed in disabled_plugins
    sed -i 's/disabled_plugins = \["cri"\]//g' /etc/containerd/config.toml

    # Restart and enable containerd service
    systemctl daemon-reload
    systemctl enable containerd
    systemctl restart containerd

    # Verify containerd is running
    if systemctl is-active --quiet containerd; then
        log_success "containerd runtime configured with SystemdCgroup=true and active."
    else
        log_error "containerd service failed to start. Please check 'systemctl status containerd'."
        exit 1
    fi
}

# --- Step 6: Kubernetes APT Repository & Packages ---
install_kubernetes_packages() {
    log_info "Configuring official Kubernetes repository (pkgs.k8s.io v${K8S_VERSION})..."

    install -m 0755 -d /etc/apt/keyrings

    # Download Kubernetes signing key
    local keyring_path="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
    curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/Release.key" | \
        gpg --dearmor -o "$keyring_path" --yes

    # Add Kubernetes source list
    cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb [signed-by=$keyring_path] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/ /
EOF

    apt-get update -y

    log_info "Installing kubelet, kubeadm, and kubectl..."
    apt-get install -y kubelet kubeadm kubectl

    # Prevent accidental automatic updates that could break cluster compatibility
    apt-mark hold kubelet kubeadm kubectl

    systemctl enable kubelet
    log_success "Kubernetes packages installed and held at current version."
}

# --- Step 7: Initialize Control Plane ---
initialize_control_plane() {
    if [[ "$SKIP_INIT" == "true" ]]; then
        log_warn "SKIP_INIT is set to true. Skipping cluster initialization."
        log_info "To manually initialize, run:"
        echo "  kubeadm init --apiserver-advertise-address=${CONTROL_PLANE_IP} --pod-network-cidr=${POD_CIDR}"
        return 0
    fi

    log_info "Pre-pulling Kubernetes control plane container images..."
    kubeadm config images pull

    log_info "Initializing Kubernetes control plane with kubeadm..."
    local init_cmd=(
        kubeadm init
        --apiserver-advertise-address="${CONTROL_PLANE_IP}"
        --pod-network-cidr="${POD_CIDR}"
    )

    "${init_cmd[@]}" | tee /root/kubeadm-init.log

    log_success "Kubernetes control plane initialized successfully!"

    # Setup kubeconfig for root
    mkdir -p /root/.kube
    cp -f /etc/kubernetes/admin.conf /root/.kube/config
    chown "$(id -u):$(id -g)" /root/.kube/config

    # Setup kubeconfig for regular sudo user if invoked via sudo
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        local user_home
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        if [[ -d "$user_home" ]]; then
            log_info "Setting up kubeconfig for user '${SUDO_USER}' in ${user_home}/.kube..."
            mkdir -p "${user_home}/.kube"
            cp -f /etc/kubernetes/admin.conf "${user_home}/.kube/config"
            chown -R "${SUDO_USER}:$(id -gn "$SUDO_USER")" "${user_home}/.kube"
        fi
    fi

    # Wait for API server to respond
    export KUBECONFIG=/etc/kubernetes/admin.conf
    log_info "Waiting for cluster API server to become ready..."
    local retry=0
    until kubectl get nodes >/dev/null 2>&1 || [[ $retry -ge 15 ]]; do
        sleep 2
        ((retry++))
    done
}

# --- Step 8: Install CNI Plugin ---
install_cni() {
    if [[ "$SKIP_INIT" == "true" ]]; then
        return 0
    fi

    export KUBECONFIG=/etc/kubernetes/admin.conf

    case "$CNI_PLUGIN" in
        flannel)
            log_info "Installing Flannel CNI plugin..."
            kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
            log_success "Flannel CNI applied."
            ;;
        calico)
            log_info "Installing Calico CNI plugin (Operator + CRD)..."
            kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.1/manifests/tigera-operator.yaml
            
            # Create custom resource matching POD_CIDR if different from default
            curl -fsSL https://raw.githubusercontent.com/projectcalico/calico/v3.28.1/manifests/custom-resources.yaml -o /tmp/calico-cr.yaml
            if [[ "$POD_CIDR" != "192.168.0.0/16" ]]; then
                sed -i "s|192.168.0.0/16|${POD_CIDR}|g" /tmp/calico-cr.yaml
            fi
            kubectl apply -f /tmp/calico-cr.yaml
            rm -f /tmp/calico-cr.yaml
            log_success "Calico CNI applied."
            ;;
        none)
            log_warn "No CNI plugin requested. Pods will remain in 'Pending' or 'NotReady' state until a CNI is installed."
            ;;
        *)
            log_warn "Unrecognized CNI plugin: '$CNI_PLUGIN'. Skipping CNI installation."
            ;;
    esac
}

# --- Step 9: Configure Single Node Cluster (Optional) ---
configure_single_node() {
    if [[ "$SKIP_INIT" == "true" || "$SINGLE_NODE" != "true" ]]; then
        return 0
    fi

    export KUBECONFIG=/etc/kubernetes/admin.conf
    log_info "Configuring single-node mode: removing control-plane taints..."

    # Untaint control-plane nodes so regular workloads can run on it
    local node_name
    node_name=$(hostname | tr '[:upper:]' '[:lower:]')
    kubectl taint nodes "$node_name" node-role.kubernetes.io/control-plane:NoSchedule- 2>/dev/null || true
    kubectl taint nodes "$node_name" node-role.kubernetes.io/master:NoSchedule- 2>/dev/null || true
    log_success "Taints removed. Workloads can now be scheduled on this control-plane node."
}

# --- Step 10: Summary & Join Command ---
print_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}==============================================================================${NC}"
    echo -e "${GREEN}${BOLD}   Kubernetes Control Plane Node Installation Completed Successfully!   ${NC}"
    echo -e "${GREEN}${BOLD}==============================================================================${NC}"
    echo ""
    if [[ "$SKIP_INIT" != "true" ]]; then
        echo -e "${BOLD}Cluster Status:${NC}"
        KUBECONFIG=/etc/kubernetes/admin.conf kubectl get nodes -o wide
        echo ""
        echo -e "${BOLD}Kubeconfig Location:${NC}"
        echo "  - Root: /root/.kube/config"
        if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
            echo "  - User (${SUDO_USER}): ~${SUDO_USER}/.kube/config"
        fi
        echo ""
        echo -e "${BOLD}To join worker nodes to this cluster, run this on each worker:${NC}"
        if [[ -f /root/kubeadm-init.log ]]; then
            echo -e "${CYAN}"
            grep -A 2 "kubeadm join" /root/kubeadm-init.log | head -n 3 || echo "  Check /root/kubeadm-init.log for the join token"
            echo -e "${NC}"
            echo "Or generate a fresh join command anytime with:"
            echo "  sudo kubeadm token create --print-join-command"
        fi
    fi
    echo ""
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
    initialize_control_plane
    install_cni
    configure_single_node
    print_summary
}

main "$@"
