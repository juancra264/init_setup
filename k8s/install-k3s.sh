#!/usr/bin/env bash
# ==============================================================================
# K3s Lightweight Kubernetes Automated Installer
# Target OS: Debian 13 (Trixie) - Minimal Server Edition
# ==============================================================================
set -euo pipefail

# --- Default Configuration Variables ---
ROLE="${ROLE:-server}"                          # Node role: server | agent
K3S_CHANNEL="${K3S_CHANNEL:-stable}"            # Release channel: stable | latest | testing (or specific v1.31)
K3S_VERSION="${K3S_VERSION:-}"                  # Specific version (e.g., v1.31.1+k3s1, overrides channel)
CLUSTER_TOKEN="${CLUSTER_TOKEN:-}"              # Cluster shared secret token (auto-generated on server if empty)
SERVER_URL="${SERVER_URL:-}"                    # Server endpoint for agent/join (e.g., https://192.168.1.100:6443)
CLUSTER_INIT="${CLUSTER_INIT:-false}"           # Enable embedded etcd for HA cluster
DATASTORE_ENDPOINT="${DATASTORE_ENDPOINT:-}"    # External datastore (e.g. postgres://, mysql://, etcd)

# Networking & CNI Options
FLANNEL_BACKEND="${FLANNEL_BACKEND:-vxlan}"     # vxlan | host-gw | wireguard-native | none
DISABLE_NETWORK_POLICY="${DISABLE_NETWORK_POLICY:-false}" # Disable k3s network-policy controller (recommended if CNI=none/Cilium)
CLUSTER_CIDR="${CLUSTER_CIDR:-10.42.0.0/16}"    # Pod network CIDR
SERVICE_CIDR="${SERVICE_CIDR:-10.43.0.0/16}"    # Service network CIDR
CLUSTER_DNS="${CLUSTER_DNS:-10.43.0.10}"        # CoreDNS IP inside service CIDR

# Bundled Components to Disable
DISABLE_TRAEFIK="${DISABLE_TRAEFIK:-false}"     # Disable built-in Traefik ingress controller
DISABLE_SERVICELB="${DISABLE_SERVICELB:-false}" # Disable built-in Klipper ServiceLB
DISABLE_LOCAL_STORAGE="${DISABLE_LOCAL_STORAGE:-false}" # Disable local-path-provisioner
DISABLE_METRICS_SERVER="${DISABLE_METRICS_SERVER:-false}" # Disable metrics-server
EXTRA_DISABLES=()                               # Additional components to disable

# Node & Certificate Settings
NODE_IP="${NODE_IP:-}"                          # Node IP to advertise (auto-detected if empty)
NODE_NAME="${NODE_NAME:-}"                      # Node name (defaults to system hostname)
TLS_SANS=()                                     # Additional IP / DNS names in certificate SAN list
NODE_LABELS=()                                  # Custom node labels (key=value)
NODE_TAINTS=()                                  # Custom node taints (key=value:effect)

# System & Behavioral Options
DISABLE_SWAP="${DISABLE_SWAP:-true}"            # Disable swap for Kubernetes stability
WRITE_KUBECONFIG_MODE="${WRITE_KUBECONFIG_MODE:-0644}" # Permissions on /etc/rancher/k3s/k3s.yaml
SETUP_COMPLETION="${SETUP_COMPLETION:-true}"    # Configure bash shell completion & aliases
WAIT_READY="${WAIT_READY:-true}"                # Wait for node to reach Ready state
WAIT_TIMEOUT="${WAIT_TIMEOUT:-300}"             # Timeout in seconds to wait for readiness

# --- Terminal Styling ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

print_banner() {
    echo -e "${CYAN}${BOLD}"
    cat <<'EOF'
  _    ____       
 | | _|___ \ ___  
 | |/ / __) / __| 
 |   < / __/\__ \ 
 |_|\_\_____|___/ 
 Lightweight Kubernetes for Debian 13 (Minimal)
EOF
    echo -e "${NC}"
}

usage() {
    cat <<EOF
Usage: sudo ./install-k3s.sh [OPTIONS]

Node Roles & Architecture:
  --role <server|agent>           Node role: 'server' (control plane) or 'agent' (worker) (default: server)
  --cluster-init                  Initialize embedded HA etcd cluster (server role only)
  --server <url>                  Server URL for worker/agent or HA join (e.g. https://192.168.1.100:6443)
  --token <token>                 Shared cluster token (auto-generated on initial server if omitted)
  --datastore <endpoint>          External datastore endpoint (PostgreSQL, MySQL, etcd)

Version & Releases:
  -v, --version <version>         Specific K3s version (e.g. v1.31.1+k3s1)
  --channel <channel>             Release channel: stable, latest, testing (default: stable)

Networking & CNI:
  --flannel-backend <backend>     Backend: vxlan, host-gw, wireguard-native, none (default: vxlan)
  --cluster-cidr <cidr>           Pod network CIDR (default: 10.42.0.0/16)
  --service-cidr <cidr>           Service network CIDR (default: 10.43.0.0/16)
  --cluster-dns <ip>              CoreDNS cluster IP (default: 10.43.0.10)
  --disable-network-policy        Disable built-in network policy controller (recommended when using Cilium/Calico)

Bundled Component Disables:
  --disable-traefik               Do not install bundled Traefik ingress controller
  --disable-servicelb             Do not install bundled Klipper ServiceLB (e.g., when using MetalLB or Cilium L2)
  --disable-local-storage         Do not install local-path-provisioner storage class
  --disable-metrics-server        Do not install metrics-server
  --disable <components>          Comma-separated list of components to disable

Node & Security Settings:
  --ip, --node-ip <ip>            Node IP address to advertise (auto-detected if omitted)
  --name, --node-name <name>      Custom node name (default: system hostname)
  --tls-san <ip-or-host>          Additional IP or DNS subject alternative name (repeatable or comma-separated)
  --node-label <key=value>        Register node with specified label (repeatable)
  --node-taint <key=value:effect> Register node with specified taint (repeatable)
  --keep-swap                     Do not disable swap (default is to disable swap permanently)
  --no-completion                 Skip configuring bash completion and 'k' alias
  --no-wait                       Do not wait for node to report Ready
  --timeout <seconds>             Seconds to wait for cluster readiness (default: 300)
  -h, --help                      Show this help message

Environment Variables:
  ROLE, K3S_VERSION, K3S_CHANNEL, CLUSTER_TOKEN, SERVER_URL, CLUSTER_INIT,
  FLANNEL_BACKEND, DISABLE_NETWORK_POLICY, CLUSTER_CIDR, SERVICE_CIDR,
  DISABLE_TRAEFIK, DISABLE_SERVICELB, DISABLE_LOCAL_STORAGE, DISABLE_METRICS_SERVER,
  NODE_IP, NODE_NAME, DISABLE_SWAP, SETUP_COMPLETION

Examples:
  # 1. Standard single-node server (ready for workloads):
  sudo ./install-k3s.sh

  # 2. Server prepared for custom CNI (e.g. Cilium) and custom Ingress:
  sudo ./install-k3s.sh --flannel-backend none --disable-network-policy --disable-traefik --disable-servicelb

  # 3. High-Availability HA Server (embedded etcd) with custom TLS SAN:
  sudo ./install-k3s.sh --cluster-init --tls-san k8s.example.com --tls-san 192.168.1.100

  # 4. Join a Worker (Agent) node to an existing K3s cluster:
  sudo ./install-k3s.sh --role agent --server https://192.168.1.100:6443 --token <CLUSTER_TOKEN>
EOF
    exit 0
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --role)
                ROLE="$2"
                shift 2
                ;;
            --cluster-init)
                CLUSTER_INIT="true"
                shift 1
                ;;
            --server)
                SERVER_URL="$2"
                shift 2
                ;;
            --token)
                CLUSTER_TOKEN="$2"
                shift 2
                ;;
            --datastore|--datastore-endpoint)
                DATASTORE_ENDPOINT="$2"
                shift 2
                ;;
            -v|--version)
                K3S_VERSION="$2"
                shift 2
                ;;
            --channel)
                K3S_CHANNEL="$2"
                shift 2
                ;;
            --flannel-backend)
                FLANNEL_BACKEND="$2"
                shift 2
                ;;
            --disable-network-policy)
                DISABLE_NETWORK_POLICY="true"
                shift 1
                ;;
            --cluster-cidr)
                CLUSTER_CIDR="$2"
                shift 2
                ;;
            --service-cidr)
                SERVICE_CIDR="$2"
                shift 2
                ;;
            --cluster-dns)
                CLUSTER_DNS="$2"
                shift 2
                ;;
            --disable-traefik)
                DISABLE_TRAEFIK="true"
                shift 1
                ;;
            --disable-servicelb)
                DISABLE_SERVICELB="true"
                shift 1
                ;;
            --disable-local-storage)
                DISABLE_LOCAL_STORAGE="true"
                shift 1
                ;;
            --disable-metrics-server)
                DISABLE_METRICS_SERVER="true"
                shift 1
                ;;
            --disable)
                IFS=',' read -r -a dis_arr <<< "$2"
                EXTRA_DISABLES+=("${dis_arr[@]}")
                shift 2
                ;;
            --ip|--node-ip)
                NODE_IP="$2"
                shift 2
                ;;
            --name|--node-name)
                NODE_NAME="$2"
                shift 2
                ;;
            --tls-san)
                IFS=',' read -r -a san_arr <<< "$2"
                TLS_SANS+=("${san_arr[@]}")
                shift 2
                ;;
            --node-label)
                NODE_LABELS+=("$2")
                shift 2
                ;;
            --node-taint)
                NODE_TAINTS+=("$2")
                shift 2
                ;;
            --keep-swap)
                DISABLE_SWAP="false"
                shift 1
                ;;
            --no-completion)
                SETUP_COMPLETION="false"
                shift 1
                ;;
            --no-wait)
                WAIT_READY="false"
                shift 1
                ;;
            --timeout)
                WAIT_TIMEOUT="$2"
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
    log_info "Running pre-flight system checks..."

    # Check root privileges
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (or with sudo)."
        exit 1
    fi

    # Validate Role
    if [[ "$ROLE" != "server" && "$ROLE" != "agent" ]]; then
        log_error "Invalid role '$ROLE'. Must be either 'server' or 'agent'."
        exit 1
    fi

    if [[ "$ROLE" == "agent" ]]; then
        if [[ -z "$SERVER_URL" ]]; then
            log_error "Worker agent role requires '--server <https://endpoint:6443>'."
            exit 1
        fi
        if [[ -z "$CLUSTER_TOKEN" ]]; then
            log_error "Worker agent role requires '--token <cluster-token>'."
            exit 1
        fi
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

    # Resource checks
    local cpu_cores
    cpu_cores=$(nproc)
    if [[ "$cpu_cores" -lt 1 ]]; then
        log_warn "At least 1 CPU core is required."
    else
        log_info "CPU Cores: $cpu_cores (OK)"
    fi

    local total_mem_mb
    total_mem_mb=$(free -m | awk '/^Mem:/{print $2}')
    if [[ "$ROLE" == "server" && "$total_mem_mb" -lt 950 ]]; then
        log_warn "Total memory is ${total_mem_mb}MB. K3s server recommends at least 1024MB (1GB) RAM."
    else
        log_info "Memory: ${total_mem_mb}MB (OK)"
    fi

    # Detect primary IP if not explicitly set
    if [[ -z "$NODE_IP" ]]; then
        NODE_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}' || true)
        if [[ -z "$NODE_IP" ]]; then
            NODE_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
        fi
    fi
    log_info "Node IP: ${NODE_IP:-127.0.0.1}"

    # Default node name
    if [[ -z "$NODE_NAME" ]]; then
        NODE_NAME=$(hostname)
    fi
    log_info "Node Name: ${NODE_NAME}"

    # Auto-add node IP and hostname to TLS SANs for servers
    if [[ "$ROLE" == "server" ]]; then
        if [[ -n "$NODE_IP" ]] && ! [[ " ${TLS_SANS[*]} " =~ " ${NODE_IP} " ]]; then
            TLS_SANS+=("$NODE_IP")
        fi
        local hostname_val
        hostname_val=$(hostname)
        if ! [[ " ${TLS_SANS[*]} " =~ " ${hostname_val} " ]]; then
            TLS_SANS+=("$hostname_val")
        fi
    fi

    log_info "Configured role: ${ROLE}"
    if [[ "$ROLE" == "server" ]]; then
        log_info "Flannel backend: ${FLANNEL_BACKEND}"
        log_info "Cluster CIDR: ${CLUSTER_CIDR}"
        log_info "Service CIDR: ${SERVICE_CIDR}"
        if [[ "$CLUSTER_INIT" == "true" ]]; then
            log_info "High-Availability mode: Embedded etcd (cluster-init) enabled"
        fi
    fi
}

# --- Step 2: System Update & Essential Minimal Tools ---
install_prerequisites() {
    log_info "Updating package lists and installing core dependencies for Debian Minimal..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y

    # Minimal Debian installations often omit curl, ca-certificates, iptables, etc.
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        gnupg \
        iproute2 \
        iptables \
        socat \
        conntrack \
        procps \
        ethtool \
        ebtables \
        tar \
        apparmor \
        apparmor-utils \
        kmod

    log_success "Prerequisite packages installed."
}

# --- Step 3: Swap Management ---
configure_swap() {
    if [[ "$DISABLE_SWAP" != "true" ]]; then
        log_info "Keeping swap enabled as requested (--keep-swap)."
        return 0
    fi

    log_info "Disabling swap for Kubernetes stability and predictability..."
    swapoff -a || true

    # Comment out swap entries in /etc/fstab
    if grep -q "swap" /etc/fstab 2>/dev/null; then
        sed -i.bak -r '/\sswap\s/s/^#?/#/' /etc/fstab
        log_info "Commented out swap entries in /etc/fstab (backup created at /etc/fstab.bak)."
    fi

    # Mask systemd swap unit if present
    systemctl mask swap.target >/dev/null 2>&1 || true
    log_success "Swap disabled permanently."
}

# --- Step 4: Kernel Modules and Sysctl for Container Networking ---
configure_kernel() {
    log_info "Configuring Linux kernel modules and sysctl network forwarding..."

    mkdir -p /etc/modules-load.d
    cat <<EOF > /etc/modules-load.d/k3s.conf
overlay
br_netfilter
EOF

    modprobe overlay || true
    modprobe br_netfilter || true

    mkdir -p /etc/sysctl.d
    cat <<EOF > /etc/sysctl.d/k3s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
net.ipv6.conf.all.forwarding         = 1
EOF

    sysctl --system >/dev/null 2>&1 || true
    log_success "Kernel modules (overlay, br_netfilter) and sysctl params applied."
}

# --- Step 5: Generate Declarative K3s Configuration ---
generate_config() {
    local config_dir="/etc/rancher/k3s"
    mkdir -p "$config_dir"
    local config_file="${config_dir}/config.yaml"

    log_info "Generating declarative K3s configuration at ${config_file}..."

    # Backup existing config if present
    if [[ -f "$config_file" ]]; then
        cp -f "$config_file" "${config_file}.bak.$(date +%s)"
        log_info "Existing config backed up."
    fi

    cat <<EOF > "$config_file"
# ==============================================================================
# K3s Declarative Configuration
# Generated automatically by install-k3s.sh
# ==============================================================================
node-name: "${NODE_NAME}"
EOF

    if [[ -n "$NODE_IP" ]]; then
        echo "node-ip: \"${NODE_IP}\"" >> "$config_file"
    fi

    if [[ "$ROLE" == "agent" ]]; then
        echo "server: \"${SERVER_URL}\"" >> "$config_file"
        echo "token: \"${CLUSTER_TOKEN}\"" >> "$config_file"
    else
        # Server-specific configurations
        echo "write-kubeconfig-mode: \"${WRITE_KUBECONFIG_MODE}\"" >> "$config_file"
        echo "cluster-cidr: \"${CLUSTER_CIDR}\"" >> "$config_file"
        echo "service-cidr: \"${SERVICE_CIDR}\"" >> "$config_file"
        echo "cluster-dns: \"${CLUSTER_DNS}\"" >> "$config_file"
        echo "flannel-backend: \"${FLANNEL_BACKEND}\"" >> "$config_file"

        if [[ "$DISABLE_NETWORK_POLICY" == "true" ]]; then
            echo "disable-network-policy: true" >> "$config_file"
        fi

        if [[ "$CLUSTER_INIT" == "true" ]]; then
            echo "cluster-init: true" >> "$config_file"
        fi

        if [[ -n "$SERVER_URL" ]]; then
            echo "server: \"${SERVER_URL}\"" >> "$config_file"
        fi

        if [[ -n "$CLUSTER_TOKEN" ]]; then
            echo "token: \"${CLUSTER_TOKEN}\"" >> "$config_file"
        fi

        if [[ -n "$DATASTORE_ENDPOINT" ]]; then
            echo "datastore-endpoint: \"${DATASTORE_ENDPOINT}\"" >> "$config_file"
        fi

        # Process disabled components
        local disabled_list=()
        if [[ "$DISABLE_TRAEFIK" == "true" ]]; then
            disabled_list+=("traefik")
        fi
        if [[ "$DISABLE_SERVICELB" == "true" ]]; then
            disabled_list+=("servicelb")
        fi
        if [[ "$DISABLE_LOCAL_STORAGE" == "true" ]]; then
            disabled_list+=("local-storage")
        fi
        if [[ "$DISABLE_METRICS_SERVER" == "true" ]]; then
            disabled_list+=("metrics-server")
        fi
        for item in "${EXTRA_DISABLES[@]}"; do
            if [[ -n "$item" ]]; then
                disabled_list+=("$item")
            fi
        done

        if [[ ${#disabled_list[@]} -gt 0 ]]; then
            echo "disable:" >> "$config_file"
            for item in "${disabled_list[@]}"; do
                echo "  - ${item}" >> "$config_file"
            done
        fi

        # Process TLS SANs
        if [[ ${#TLS_SANS[@]} -gt 0 ]]; then
            echo "tls-san:" >> "$config_file"
            for san in "${TLS_SANS[@]}"; do
                if [[ -n "$san" ]]; then
                    echo "  - \"${san}\"" >> "$config_file"
                fi
            done
        fi
    fi

    # Process node labels
    if [[ ${#NODE_LABELS[@]} -gt 0 ]]; then
        echo "node-label:" >> "$config_file"
        for label in "${NODE_LABELS[@]}"; do
            echo "  - \"${label}\"" >> "$config_file"
        done
    fi

    # Process node taints
    if [[ ${#NODE_TAINTS[@]} -gt 0 ]]; then
        echo "node-taint:" >> "$config_file"
        for taint in "${NODE_TAINTS[@]}"; do
            echo "  - \"${taint}\"" >> "$config_file"
        done
    fi

    chmod 0600 "$config_file"
    log_success "K3s configuration file generated successfully."
}

# --- Step 6: Install K3s via Official Script ---
install_k3s() {
    log_info "Installing K3s using official installation manager..."

    # Configure installer environment variables
    export INSTALL_K3S_CHANNEL="${K3S_CHANNEL}"

    if [[ -n "$K3S_VERSION" ]]; then
        export INSTALL_K3S_VERSION="${K3S_VERSION}"
        log_info "Target K3s version: ${K3S_VERSION}"
    else
        log_info "Target K3s release channel: ${K3S_CHANNEL}"
    fi

    # Select execution mode (server or agent)
    local install_mode_args=()
    if [[ "$ROLE" == "agent" ]]; then
        log_info "Executing installer in agent/worker mode..."
        export K3S_URL="${SERVER_URL}"
        export K3S_TOKEN="${CLUSTER_TOKEN}"
    else
        log_info "Executing installer in server/control-plane mode..."
    fi

    # Execute official installer
    curl -sfL https://get.k3s.io | sh -s - "${install_mode_args[@]}"

    local service_name="k3s"
    if [[ "$ROLE" == "agent" ]]; then
        service_name="k3s-agent"
    fi

    systemctl daemon-reload
    systemctl enable "$service_name"
    systemctl restart "$service_name"

    log_success "K3s ${service_name} binary and systemd service installed."
}

# --- Step 7: Kubeconfig Setup & Permissions ---
setup_kubeconfig() {
    if [[ "$ROLE" == "agent" ]]; then
        return 0
    fi

    log_info "Configuring kubeconfig access for administrative and regular users..."
    local source_kubeconfig="/etc/rancher/k3s/k3s.yaml"

    local retry=0
    until [[ -f "$source_kubeconfig" ]] || [[ $retry -ge 30 ]]; do
        sleep 1
        ((retry++))
    done

    if [[ ! -f "$source_kubeconfig" ]]; then
        log_error "Kubeconfig file $source_kubeconfig not found after installation."
        exit 1
    fi

    # Set root kubeconfig
    mkdir -p /root/.kube
    cp -f "$source_kubeconfig" /root/.kube/config
    chmod 0600 /root/.kube/config

    # Modify copy for external/node IP access if primary IP is known
    if [[ -n "$NODE_IP" && "$NODE_IP" != "127.0.0.1" ]]; then
        sed -i "s|127.0.0.1:6443|${NODE_IP}:6443|g" /root/.kube/config
    fi

    # Configure regular sudo user's kubeconfig if invoked via sudo
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        local user_home
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        if [[ -d "$user_home" ]]; then
            log_info "Configuring kubeconfig for user '${SUDO_USER}' in ${user_home}/.kube..."
            mkdir -p "${user_home}/.kube"
            cp -f /root/.kube/config "${user_home}/.kube/config"
            chown -R "${SUDO_USER}:$(id -gn "$SUDO_USER")" "${user_home}/.kube"
            chmod 0600 "${user_home}/.kube/config"
        fi
    fi

    log_success "Kubeconfig files configured."
}

# --- Step 8: Configure Shell Autocompletion and Aliases ---
setup_shell_environment() {
    if [[ "$SETUP_COMPLETION" != "true" ]]; then
        return 0
    fi

    log_info "Setting up bash autocompletion and aliases..."

    mkdir -p /etc/bash_completion.d

    # K3s & Kubectl completions
    if command -v k3s >/dev/null 2>&1; then
        k3s completion bash > /etc/bash_completion.d/k3s 2>/dev/null || true
    fi

    if command -v kubectl >/dev/null 2>&1; then
        kubectl completion bash > /etc/bash_completion.d/kubectl 2>/dev/null || true
    fi

    if command -v crictl >/dev/null 2>&1; then
        crictl completion bash > /etc/bash_completion.d/crictl 2>/dev/null || true
    fi

    # Configure convenient 'k' alias and KUBECONFIG export in /etc/profile.d/k3s.sh
    cat <<'EOF' > /etc/profile.d/k3s.sh
# K3s shell enhancements
if [ -z "${KUBECONFIG:-}" ] && [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

if command -v kubectl >/dev/null 2>&1; then
    alias k=kubectl
    complete -o default -F __start_kubectl k 2>/dev/null || true
fi
EOF
    chmod 0644 /etc/profile.d/k3s.sh

    # Setup crictl default endpoint for containerd
    if [[ ! -f /etc/crictl.yaml ]]; then
        cat <<'EOF' > /etc/crictl.yaml
runtime-endpoint: unix:///run/k3s/containerd/containerd.sock
image-endpoint: unix:///run/k3s/containerd/containerd.sock
timeout: 10
debug: false
EOF
    fi

    log_success "Shell autocompletion and 'k=kubectl' alias configured."
}

# --- Step 9: Wait for Cluster Readiness ---
wait_for_readiness() {
    if [[ "$WAIT_READY" != "true" ]]; then
        return 0
    fi

    local service_name="k3s"
    if [[ "$ROLE" == "agent" ]]; then
        service_name="k3s-agent"
    fi

    log_info "Waiting for ${service_name} service to become active..."
    local elapsed=0
    until systemctl is-active --quiet "$service_name" || [[ $elapsed -ge 60 ]]; do
        sleep 2
        ((elapsed+=2))
    done

    if ! systemctl is-active --quiet "$service_name"; then
        log_error "${service_name} failed to become active. Check 'journalctl -u ${service_name} -e'."
        exit 1
    fi
    log_success "${service_name} systemd service is active."

    # If server, verify node readiness via kubectl
    if [[ "$ROLE" == "server" ]]; then
        log_info "Waiting for Kubernetes API and node to report 'Ready' status (timeout: ${WAIT_TIMEOUT}s)..."
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        local start_time
        start_time=$(date +%s)

        while true; do
            local current_time
            current_time=$(date +%s)
            if (( current_time - start_time >= WAIT_TIMEOUT )); then
                log_warn "Timeout reached waiting for node readiness. Node may still be initializing CNI or images."
                break
            fi

            if kubectl get nodes 2>/dev/null | grep -E "\bReady\b" >/dev/null 2>&1; then
                log_success "K3s node is Ready!"
                break
            fi

            # If flannel is none, node might stay NotReady until CNI (e.g. Cilium) is installed
            if [[ "$FLANNEL_BACKEND" == "none" ]]; then
                if kubectl get nodes >/dev/null 2>&1; then
                    log_info "Kubernetes API server is responding. (Node remains NotReady as expected until external CNI is deployed)."
                    break
                fi
            fi

            sleep 3
        done
    fi
}

# --- Step 10: Print Summary & Instructions ---
print_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}==============================================================================${NC}"
    if [[ "$ROLE" == "server" ]]; then
        echo -e "${GREEN}${BOLD}      K3s Control Plane Server Installation Completed Successfully!           ${NC}"
    else
        echo -e "${GREEN}${BOLD}      K3s Worker Node (Agent) Installation Completed Successfully!            ${NC}"
    fi
    echo -e "${GREEN}${BOLD}==============================================================================${NC}"
    echo ""

    if [[ "$ROLE" == "server" ]]; then
        local token_file="/var/lib/rancher/k3s/server/node-token"
        local server_token=""
        if [[ -f "$token_file" ]]; then
            server_token=$(cat "$token_file")
        fi

        echo -e "${BOLD}Node & Cluster Status:${NC}"
        KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get nodes -o wide || true
        echo ""
        echo -e "${BOLD}System Pods:${NC}"
        KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get pods -A || true
        echo ""
        echo -e "${BOLD}Kubeconfig Access:${NC}"
        echo "  - System config:  /etc/rancher/k3s/k3s.yaml (mode: ${WRITE_KUBECONFIG_MODE})"
        echo "  - Root config:    /root/.kube/config"
        if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
            echo "  - User config:    ~${SUDO_USER}/.kube/config"
        fi
        echo "  - Environment:    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
        echo "  - Alias:          'k' is aliased to 'kubectl'"
        echo ""
        echo -e "${BOLD}Worker (Agent) Node Join Information:${NC}"
        echo "  To join a worker node to this cluster, run the following command on the worker machine:"
        echo -e "${CYAN}${BOLD}"
        echo "  sudo ./install-k3s.sh --role agent \\"
        echo "    --server https://${NODE_IP:-<SERVER_IP>}:6443 \\"
        echo "    --token ${server_token:-<CLUSTER_TOKEN>}"
        echo -e "${NC}"
        if [[ "$CLUSTER_INIT" == "true" ]]; then
            echo -e "${BOLD}High-Availability Additional Server Join Information:${NC}"
            echo "  To join an additional control-plane server node:"
            echo -e "${CYAN}${BOLD}"
            echo "  sudo ./install-k3s.sh --role server \\"
            echo "    --server https://${NODE_IP:-<SERVER_IP>}:6443 \\"
            echo "    --token ${server_token:-<CLUSTER_TOKEN>}"
            echo -e "${NC}"
        fi
        if [[ "$FLANNEL_BACKEND" == "none" ]]; then
            echo -e "${YELLOW}${BOLD}Note regarding CNI:${NC}"
            echo "  Flannel backend is set to 'none'. Install your preferred CNI (e.g. Cilium) now:"
            echo "  sudo ./install-cilium.sh"
            echo ""
        fi
        echo -e "${BOLD}Service Management & Uninstall:${NC}"
        echo "  - Service status:   systemctl status k3s"
        echo "  - Service logs:     journalctl -u k3s -f"
        echo "  - Killall script:   /usr/local/bin/k3s-killall.sh"
        echo "  - Uninstall script: /usr/local/bin/k3s-uninstall.sh"
    else
        echo -e "${BOLD}Worker Agent Service Status:${NC}"
        systemctl status k3s-agent --no-pager || true
        echo ""
        echo -e "${BOLD}Service Management & Uninstall:${NC}"
        echo "  - Service status:   systemctl status k3s-agent"
        echo "  - Service logs:     journalctl -u k3s-agent -f"
        echo "  - Killall script:   /usr/local/bin/k3s-killall.sh"
        echo "  - Uninstall script: /usr/local/bin/k3s-agent-uninstall.sh"
    fi
    echo ""
}

# --- Main Entry Point ---
main() {
    print_banner
    parse_arguments "$@"
    preflight_checks
    install_prerequisites
    configure_swap
    configure_kernel
    generate_config
    install_k3s
    setup_kubeconfig
    setup_shell_environment
    wait_for_readiness
    print_summary
}

main "$@"
