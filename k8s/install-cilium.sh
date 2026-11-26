#!/usr/bin/env bash
# ==============================================================================
# Cilium eBPF CNI Automated Installer & Activator for Kubernetes
# Target OS: Debian 13 (Trixie) - Minimal Server Edition
# ==============================================================================
set -euo pipefail

# --- Default Configuration Variables ---
CILIUM_CLI_VERSION="${CILIUM_CLI_VERSION:-latest}"      # Target Cilium CLI version (or 'latest')
CILIUM_VERSION="${CILIUM_VERSION:-}"                    # Target Cilium image/chart version (empty = CLI default stable)
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"            # Binary destination directory for cilium CLI
KUBECONFIG_PATH="${KUBECONFIG:-}"                       # Custom kubeconfig path (auto-detected if empty)
POD_CIDR="${POD_CIDR:-}"                                # Pod network CIDR (auto-detected from cluster if empty)
KUBE_PROXY_REPLACEMENT="${KUBE_PROXY_REPLACEMENT:-true}" # true | false | strict
ROUTING_MODE="${ROUTING_MODE:-tunnel}"                  # tunnel | native
TUNNEL_PROTOCOL="${TUNNEL_PROTOCOL:-vxlan}"             # vxlan | geneve (used if ROUTING_MODE=tunnel)
ENABLE_HUBBLE="${ENABLE_HUBBLE:-false}"                 # Enable Hubble observability
ENABLE_HUBBLE_UI="${ENABLE_HUBBLE_UI:-false}"           # Enable Hubble Web UI (implies ENABLE_HUBBLE=true)
RUN_CONNECTIVITY_TEST="${RUN_CONNECTIVITY_TEST:-false}" # Run 'cilium connectivity test' post-install
SKIP_WAIT="${SKIP_WAIT:-false}"                         # Skip waiting for Cilium pods to become ready
WAIT_TIMEOUT="${WAIT_TIMEOUT:-900s}"                    # Timeout duration for Cilium status wait
SETUP_COMPLETION="${SETUP_COMPLETION:-true}"            # Configure bash autocompletion

# Fallback stable versions if dynamic GitHub resolution fails
FALLBACK_CLI_VERSION="v0.16.20"
FALLBACK_CILIUM_VERSION="1.16.2"

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
    echo -e "${MAGENTA}${BOLD}"
    cat <<'EOF'
   ____ _ _ _                 
  / ___(_) (_)_   _ _ __ ___  
 | |   | | | | | | | '_ ` _ \ 
 | |___| | | | |_| | | | | | |
  \____|_|_|_|\__,_|_| |_| |_|
 eBPF-Based Networking & Security for Kubernetes
 Target OS: Debian 13 (Trixie) Minimal
EOF
    echo -e "${NC}"
}

usage() {
    cat <<EOF
Usage: sudo ./install-cilium.sh [OPTIONS]

Options:
  -v, --version <version>             Cilium release version (e.g. 1.16.2, default: CLI latest stable)
  --cli-version <version>             Cilium CLI binary version (default: latest)
  -k, --kubeconfig <path>             Path to kubeconfig file (default: auto-detected)
  -p, --pod-cidr <cidr>               Cluster Pod CIDR (default: auto-detected from cluster or 10.244.0.0/16)
  --kube-proxy-replacement <mode>     Kube-Proxy replacement mode: true, false, or strict (default: true)
  --routing-mode <mode>               Routing mode: tunnel or native (default: tunnel)
  --tunnel-protocol <proto>           Tunnel encapsulation protocol: vxlan or geneve (default: vxlan)
  --hubble                            Enable Hubble observability
  --hubble-ui                         Enable Hubble observability AND Hubble Web UI
  --test                              Execute Cilium network connectivity test after installation
  --skip-wait                         Do not wait for Cilium pods to become healthy and ready
  --timeout <duration>                Timeout duration when waiting for readiness (default: 900s)
  --no-completion                     Skip bash autocompletion setup
  -d, --dir <path>                    Directory to install cilium CLI binary (default: /usr/local/bin)
  -h, --help                          Show this help message

Environment variables:
  CILIUM_VERSION, CILIUM_CLI_VERSION, KUBECONFIG, POD_CIDR, KUBE_PROXY_REPLACEMENT,
  ROUTING_MODE, TUNNEL_PROTOCOL, ENABLE_HUBBLE, ENABLE_HUBBLE_UI, RUN_CONNECTIVITY_TEST

Examples:
  # Standard installation (auto-detects kubeconfig and pod CIDR)
  sudo ./install-cilium.sh

  # Install with Hubble Observability and Web UI enabled
  sudo ./install-cilium.sh --hubble-ui

  # Install with full Kube-Proxy replacement and run connectivity test
  sudo ./install-cilium.sh --kube-proxy-replacement strict --test

  # Install specific Cilium version
  sudo ./install-cilium.sh --version 1.16.2
EOF
    exit 0
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--version)
                CILIUM_VERSION="$2"
                shift 2
                ;;
            --cli-version)
                CILIUM_CLI_VERSION="$2"
                shift 2
                ;;
            -k|--kubeconfig)
                KUBECONFIG_PATH="$2"
                shift 2
                ;;
            -p|--pod-cidr)
                POD_CIDR="$2"
                shift 2
                ;;
            --kube-proxy-replacement)
                KUBE_PROXY_REPLACEMENT="$2"
                shift 2
                ;;
            --routing-mode)
                ROUTING_MODE="$2"
                shift 2
                ;;
            --tunnel-protocol)
                TUNNEL_PROTOCOL="$2"
                shift 2
                ;;
            --hubble)
                ENABLE_HUBBLE="true"
                shift 1
                ;;
            --hubble-ui)
                ENABLE_HUBBLE="true"
                ENABLE_HUBBLE_UI="true"
                shift 1
                ;;
            --test|--connectivity-test)
                RUN_CONNECTIVITY_TEST="true"
                shift 1
                ;;
            --skip-wait)
                SKIP_WAIT="true"
                shift 1
                ;;
            --timeout)
                WAIT_TIMEOUT="$2"
                shift 2
                ;;
            --no-completion)
                SETUP_COMPLETION="false"
                shift 1
                ;;
            -d|--dir)
                INSTALL_DIR="$2"
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

    # Ensure root privileges
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo privileges."
        exit 1
    fi

    # Verify Linux OS
    local os_type
    os_type="$(uname -s | tr '[:upper:]' '[:lower:]')"
    if [[ "$os_type" != "linux" ]]; then
        log_error "Unsupported operating system: $os_type (Linux required)"
        exit 1
    fi

    # Check Linux Kernel Version (eBPF requires >= 5.4, modern Cilium prefers >= 5.10 / 6.x)
    local kernel_ver
    kernel_ver="$(uname -r | cut -d- -f1)"
    local k_major k_minor
    k_major="$(echo "$kernel_ver" | cut -d. -f1)"
    k_minor="$(echo "$kernel_ver" | cut -d. -f2)"

    if [[ "$k_major" -lt 5 || ( "$k_major" -eq 5 && "$k_minor" -lt 4 ) ]]; then
        log_warn "Linux kernel version $kernel_ver is below 5.4. eBPF features might be restricted."
    else
        log_success "Linux Kernel version ($kernel_ver) satisfies Cilium eBPF requirements."
    fi

    # Detect CPU Architecture
    local raw_arch
    raw_arch="$(uname -m)"
    case "$raw_arch" in
        x86_64|amd64)
            TARGET_ARCH="amd64"
            ;;
        aarch64|arm64)
            TARGET_ARCH="arm64"
            ;;
        *)
            log_error "Unsupported CPU architecture: $raw_arch. Cilium CLI requires amd64 or arm64."
            exit 1
            ;;
    esac
    log_info "Detected architecture: $raw_arch (CLI target: $TARGET_ARCH)"

    # Locate Kubeconfig
    locate_kubeconfig

    # Verify cluster connectivity via kubectl
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "kubectl command not found. Please ensure Kubernetes control plane tools are installed."
        exit 1
    fi

    log_info "Verifying Kubernetes cluster reachability..."
    if ! kubectl get nodes >/dev/null 2>&1; then
        log_error "Cannot communicate with the Kubernetes cluster using KUBECONFIG='${KUBECONFIG}'."
        log_error "Please verify that the control plane is running and your kubeconfig is valid."
        exit 1
    fi
    log_success "Kubernetes cluster is reachable."
}

# --- Locate Kubeconfig Helper ---
locate_kubeconfig() {
    local resolved=""
    if [[ -n "$KUBECONFIG_PATH" && -f "$KUBECONFIG_PATH" ]]; then
        resolved="$KUBECONFIG_PATH"
    elif [[ -n "${KUBECONFIG:-}" && -f "$KUBECONFIG" ]]; then
        resolved="$KUBECONFIG"
    elif [[ -f "/etc/kubernetes/admin.conf" ]]; then
        resolved="/etc/kubernetes/admin.conf"
    elif [[ -f "${HOME}/.kube/config" ]]; then
        resolved="${HOME}/.kube/config"
    elif [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        local user_home
        user_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
        if [[ -f "${user_home}/.kube/config" ]]; then
            resolved="${user_home}/.kube/config"
        fi
    fi

    if [[ -z "$resolved" ]]; then
        log_error "No valid kubeconfig found. Checked custom path, /etc/kubernetes/admin.conf, and ~/.kube/config."
        exit 1
    fi

    export KUBECONFIG="$resolved"
    log_info "Using Kubeconfig: $KUBECONFIG"
}

# --- Step 2: Install Debian 13 Minimal Dependencies ---
install_prerequisites() {
    log_info "Checking prerequisite packages for Debian 13 minimal..."
    local required_pkgs=(
        curl
        tar
        gzip
        ca-certificates
        coreutils
        iproute2
        iptables
        socat
        conntrack
        procps
    )

    local missing=()
    for pkg in "${required_pkgs[@]}"; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            missing+=("$pkg")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_info "Installing missing minimal system packages: ${missing[*]}..."
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y
        apt-get install -y --no-install-recommends "${missing[@]}"
        log_success "Minimal dependencies installed."
    else
        log_info "All prerequisite system packages are already installed."
    fi
}

# --- Step 3: Configure Kernel Modules, BPF Filesystem & Sysctl ---
configure_kernel_and_bpf() {
    log_info "Configuring kernel modules, eBPF filesystem, and sysctl for Cilium..."

    # 1. Load required and recommended kernel modules for Cilium
    local modules=(cls_bpf sch_ingress veth vxlan geneve)
    for mod in "${modules[@]}"; do
        if ! lsmod | grep -q "^${mod}\b"; then
            modprobe "$mod" 2>/dev/null || log_warn "Could not load module $mod (it may be built into kernel)."
        fi
    done

    # Persist modules across reboot
    mkdir -p /etc/modules-load.d
    cat <<'EOF' > /etc/modules-load.d/cilium.conf
# Kernel modules for Cilium eBPF CNI
cls_bpf
sch_ingress
veth
vxlan
geneve
EOF
    log_info "Kernel modules configured and persisted in /etc/modules-load.d/cilium.conf."

    # 2. Mount and persist BPF Filesystem (bpffs) at /sys/fs/bpf
    mkdir -p /sys/fs/bpf
    if ! mountpoint -q /sys/fs/bpf; then
        log_info "Mounting eBPF filesystem at /sys/fs/bpf..."
        mount bpffs /sys/fs/bpf -t bpf
    fi

    # Ensure persistence in /etc/fstab
    if ! grep -qs '/sys/fs/bpf' /etc/fstab; then
        log_info "Persisting /sys/fs/bpf mount in /etc/fstab..."
        echo "bpffs /sys/fs/bpf bpf defaults 0 0" >> /etc/fstab
    fi
    log_success "eBPF filesystem (bpffs) is mounted and persistent."

    # 3. Apply Cilium sysctl optimizations
    mkdir -p /etc/sysctl.d
    cat <<'EOF' > /etc/sysctl.d/99-cilium.conf
# Cilium & eBPF Networking Optimizations
net.core.bpf_jit_enable = 1
net.core.bpf_jit_harden = 0
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
EOF
    sysctl --system >/dev/null 2>&1 || true
    log_info "Cilium sysctl parameters applied and persisted in /etc/sysctl.d/99-cilium.conf."
}

# --- Step 4: Download & Install Cilium CLI ---
install_cilium_cli() {
    # Check if cilium CLI is already installed and functional
    if command -v cilium >/dev/null 2>&1; then
        local current_cli_ver
        current_cli_ver="$(cilium version --client 2>/dev/null | grep -Po 'cilium-cli:\s*\K[^\s]+' || echo "installed")"
        log_info "Found existing Cilium CLI (${current_cli_ver}) at $(command -v cilium)."
        if [[ "$CILIUM_CLI_VERSION" != "latest" && "$CILIUM_CLI_VERSION" != "$current_cli_ver" && -n "$CILIUM_CLI_VERSION" ]]; then
            log_info "Requested version ($CILIUM_CLI_VERSION) differs from existing. Updating Cilium CLI..."
        else
            log_info "Cilium CLI is ready."
            return 0
        fi
    fi

    # Resolve Cilium CLI version
    local target_cli_ver="$CILIUM_CLI_VERSION"
    if [[ "$target_cli_ver" == "latest" || -z "$target_cli_ver" ]]; then
        log_info "Resolving latest stable Cilium CLI version..."
        local resolved_cli=""
        resolved_cli="$(curl -sSfL "https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt" 2>/dev/null | tr -d '[:space:]' || true)"
        if [[ -n "$resolved_cli" && "$resolved_cli" =~ ^v[0-9]+\.[0-9]+ ]]; then
            target_cli_ver="$resolved_cli"
        else
            log_warn "Failed to fetch latest Cilium CLI tag from GitHub. Using fallback: $FALLBACK_CLI_VERSION"
            target_cli_ver="$FALLBACK_CLI_VERSION"
        fi
    fi

    # Ensure version prefix has 'v'
    if [[ ! "$target_cli_ver" =~ ^v ]]; then
        target_cli_ver="v${target_cli_ver}"
    fi

    log_info "Installing Cilium CLI version: ${target_cli_ver} (${TARGET_ARCH})..."

    local tmp_dir
    tmp_dir="$(mktemp -d -t cilium-cli-install-XXXXXX)"
    trap 'rm -rf "$tmp_dir"' EXIT

    local tarball="cilium-linux-${TARGET_ARCH}.tar.gz"
    local checksum_file="${tarball}.sha256sum"
    local base_url="https://github.com/cilium/cilium-cli/releases/download/${target_cli_ver}"

    log_info "Downloading ${base_url}/${tarball}..."
    if ! curl -sSfL "${base_url}/${tarball}" -o "${tmp_dir}/${tarball}"; then
        log_error "Failed to download Cilium CLI from ${base_url}/${tarball}"
        exit 1
    fi

    # Verify checksum if available
    if curl -sSfL "${base_url}/${checksum_file}" -o "${tmp_dir}/${checksum_file}" 2>/dev/null; then
        log_info "Verifying SHA256 checksum..."
        local expected_hash actual_hash
        expected_hash="$(awk '{print $1}' "${tmp_dir}/${checksum_file}" | tr -d '[:space:]')"
        actual_hash="$(sha256sum "${tmp_dir}/${tarball}" | awk '{print $1}' | tr -d '[:space:]')"

        if [[ "$expected_hash" != "$actual_hash" ]]; then
            log_error "Cilium CLI checksum mismatch!"
            log_error "Expected: $expected_hash"
            log_error "Actual:   $actual_hash"
            exit 1
        fi
        log_success "Checksum verified ($actual_hash)."
    fi

    log_info "Extracting binary..."
    tar -zxvf "${tmp_dir}/${tarball}" -C "$tmp_dir" >/dev/null

    mkdir -p "$INSTALL_DIR"
    install -m 755 "${tmp_dir}/cilium" "${INSTALL_DIR}/cilium"

    if ! "${INSTALL_DIR}/cilium" version --client >/dev/null 2>&1; then
        log_error "Cilium CLI installation failed verification."
        exit 1
    fi

    local installed_cli_ver
    installed_cli_ver="$("${INSTALL_DIR}/cilium" version --client | grep -Po 'cilium-cli:\s*\K[^\s]+' || echo "${target_cli_ver}")"
    log_success "Cilium CLI installed successfully: ${installed_cli_ver} at ${INSTALL_DIR}/cilium"
}

# --- Step 5: Detect Cluster Settings & Existing CNI ---
detect_cluster_settings() {
    log_info "Inspecting Kubernetes cluster environment..."

    # 1. Detect existing conflicting CNI plugins
    local existing_cnis=()
    if kubectl get daemonset -n kube-system kube-flannel-ds >/dev/null 2>&1; then
        existing_cnis+=("Flannel")
    fi
    if kubectl get daemonset -n calico-system calico-node >/dev/null 2>&1 || kubectl get daemonset -n kube-system calico-node >/dev/null 2>&1; then
        existing_cnis+=("Calico")
    fi
    if kubectl get daemonset -n kube-system weave-net >/dev/null 2>&1; then
        existing_cnis+=("Weave")
    fi

    if [[ ${#existing_cnis[@]} -gt 0 ]]; then
        log_warn "Detected existing active CNI plugin(s): ${existing_cnis[*]}."
        log_warn "Installing Cilium alongside existing CNIs may cause network conflicts."
        log_warn "If migrating from Flannel or Calico, consider chaining or removing them before proceeding."
    fi

    # 2. Auto-discover Pod CIDR if not explicitly supplied
    if [[ -z "$POD_CIDR" ]]; then
        log_info "Auto-detecting cluster Pod CIDR..."
        local discovered_cidr=""
        # Try kubeadm-config ConfigMap
        discovered_cidr="$(kubectl get cm -n kube-system kubeadm-config -o jsonpath='{.data.ClusterConfiguration}' 2>/dev/null \
            | grep -Po 'podSubnet:\s*\K[^\s]+' || true)"

        # Fallback: check node spec podCIDR
        if [[ -z "$discovered_cidr" ]]; then
            discovered_cidr="$(kubectl get nodes -o jsonpath='{.items[0].spec.podCIDR}' 2>/dev/null || true)"
        fi

        if [[ -n "$discovered_cidr" ]]; then
            POD_CIDR="$discovered_cidr"
            log_success "Discovered Pod CIDR: $POD_CIDR"
        else
            POD_CIDR="10.244.0.0/16"
            log_warn "Could not auto-detect cluster pod CIDR. Falling back to default: $POD_CIDR"
        fi
    else
        log_info "Using specified Pod CIDR: $POD_CIDR"
    fi

    # 3. Detect API Server Host & Port (required for robust Kube-Proxy replacement)
    API_SERVER_ENDPOINT="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || true)"
    API_HOST=""
    API_PORT=""
    if [[ -n "$API_SERVER_ENDPOINT" ]]; then
        # Parse protocol://host:port
        local sanitized="${API_SERVER_ENDPOINT#*://}"
        API_HOST="${sanitized%%:*}"
        API_PORT="${sanitized##*:}"
        # If host and port are identical, default port is 6443
        if [[ "$API_PORT" == "$API_HOST" ]]; then
            API_PORT="6443"
        fi
        log_info "Detected Kubernetes API endpoint: host=${API_HOST}, port=${API_PORT}"
    fi
}

# --- Step 6: Install & Activate Cilium CNI ---
install_cilium_cni() {
    log_info "Deploying and activating Cilium CNI on the cluster..."

    local install_cmd=(
        cilium install
        --set "ipam.operator.clusterPoolIPv4PodCIDRList=${POD_CIDR}"
        --set "routingMode=${ROUTING_MODE}"
    )

    # Version specification
    if [[ -n "$CILIUM_VERSION" ]]; then
        install_cmd+=(--version "$CILIUM_VERSION")
    fi

    # Routing mode specifics
    if [[ "$ROUTING_MODE" == "tunnel" ]]; then
        install_cmd+=(--set "tunnelProtocol=${TUNNEL_PROTOCOL}")
    fi

    # Kube-Proxy replacement settings
    if [[ "$KUBE_PROXY_REPLACEMENT" == "true" || "$KUBE_PROXY_REPLACEMENT" == "strict" ]]; then
        log_info "Configuring Kube-Proxy replacement (mode: ${KUBE_PROXY_REPLACEMENT})..."
        install_cmd+=(--set "kubeProxyReplacement=${KUBE_PROXY_REPLACEMENT}")

        if [[ -n "$API_HOST" && -n "$API_PORT" ]]; then
            install_cmd+=(
                --set "k8sServiceHost=${API_HOST}"
                --set "k8sServicePort=${API_PORT}"
            )
        fi
    else
        install_cmd+=(--set "kubeProxyReplacement=false")
    fi

    # Wait behavior during install
    if [[ "$SKIP_WAIT" != "true" ]]; then
        install_cmd+=(--wait --wait-duration "$WAIT_TIMEOUT")
    fi

    log_info "Executing: ${install_cmd[*]}"
    "${install_cmd[@]}"
    log_success "Cilium installation command completed."
}

# --- Step 7: Configure Hubble Observability (Optional) ---
configure_hubble() {
    if [[ "$ENABLE_HUBBLE" != "true" && "$ENABLE_HUBBLE_UI" != "true" ]]; then
        return 0
    fi

    log_info "Enabling Hubble observability on Cilium..."
    local hubble_cmd=(cilium hubble enable)

    if [[ "$ENABLE_HUBBLE_UI" == "true" ]]; then
        log_info "Enabling Hubble Web UI..."
        hubble_cmd+=(--ui)
    fi

    "${hubble_cmd[@]}"
    log_success "Hubble configuration applied."
}

# --- Step 8: Verify Cluster & Cilium Status ---
verify_cilium_status() {
    if [[ "$SKIP_WAIT" == "true" ]]; then
        log_info "Skipping wait verification (--skip-wait specified)."
        return 0
    fi

    log_info "Waiting for Cilium components to be fully healthy and operational..."
    if ! cilium status --wait --wait-duration "$WAIT_TIMEOUT"; then
        log_warn "Cilium status check timed out or reported warnings. Inspecting pods..."
        kubectl get pods -n kube-system -l k8s-app=cilium -o wide || true
    else
        log_success "All Cilium agents and operator pods are operational!"
    fi

    # Verify nodes have transitioned to Ready
    log_info "Checking Kubernetes node status..."
    local retry=0
    local all_ready=false
    while [[ $retry -lt 15 ]]; do
        if ! kubectl get nodes --no-headers | awk '{print $2}' | grep -qv "Ready"; then
            all_ready=true
            break
        fi
        sleep 3
        ((retry++))
    done

    if [[ "$all_ready" == "true" ]]; then
        log_success "All Kubernetes nodes are in 'Ready' state."
    else
        log_warn "Some nodes may still be transitioning to 'Ready' state."
    fi
}

# --- Step 9: Run Connectivity Test (Optional) ---
run_connectivity_test() {
    if [[ "$RUN_CONNECTIVITY_TEST" != "true" ]]; then
        return 0
    fi

    log_info "Running Cilium connectivity test suite (this may take a few minutes)..."
    cilium connectivity test || log_warn "Connectivity test completed with warnings or failures."
}

# --- Step 10: Configure Shell Autocompletion ---
configure_completion() {
    if [[ "$SETUP_COMPLETION" != "true" ]]; then
        return 0
    fi

    log_info "Configuring bash shell autocompletion for Cilium CLI..."
    local completion_dir="/etc/bash_completion.d"
    if [[ -d "$completion_dir" && -w "$completion_dir" ]]; then
        cilium completion bash > "${completion_dir}/cilium"
        chmod 644 "${completion_dir}/cilium"
        log_success "Bash completion installed to ${completion_dir}/cilium"
    fi

    # Setup for invoking sudo user
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        local user_home
        user_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
        local user_bashrc="${user_home}/.bashrc"
        if [[ -f "$user_bashrc" ]] && ! grep -q "cilium completion bash" "$user_bashrc"; then
            echo "" >> "$user_bashrc"
            echo "# Cilium CLI bash completion" >> "$user_bashrc"
            echo "source <(cilium completion bash)" >> "$user_bashrc"
            chown "${SUDO_USER}:$(id -gn "$SUDO_USER")" "$user_bashrc"
            log_success "Bash completion added to ${user_bashrc}"
        fi
    fi
}

# --- Step 11: Summary & Usage Instructions ---
print_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}==============================================================================${NC}"
    echo -e "${GREEN}${BOLD}         Cilium eBPF CNI Installation & Activation Complete!          ${NC}"
    echo -e "${GREEN}${BOLD}==============================================================================${NC}"
    echo ""
    echo -e "${BOLD}Cilium Status Overview:${NC}"
    cilium status 2>/dev/null || kubectl get pods -n kube-system -l k8s-app=cilium
    echo ""
    echo -e "${BOLD}Kubernetes Nodes:${NC}"
    kubectl get nodes -o wide
    echo ""
    echo -e "${BOLD}Useful Commands:${NC}"
    echo "  - Check Cilium health:      cilium status"
    echo "  - Inspect eBPF endpoints:   cilium endpoint list"
    echo "  - Monitor network traffic:  cilium monitor"
    echo "  - Run connectivity tests:   cilium connectivity test"
    if [[ "$ENABLE_HUBBLE" == "true" ]]; then
        echo "  - Port-forward Hubble UI:   cilium hubble ui"
        echo "  - Stream Hubble flows:      cilium hubble port-forward &"
        echo "                              cilium hubble observe"
    else
        echo "  - Enable Hubble anytime:    sudo ./install-cilium.sh --hubble-ui"
    fi
    echo ""
}

# --- Main Entry Point ---
main() {
    print_banner
    parse_arguments "$@"
    preflight_checks
    install_prerequisites
    configure_kernel_and_bpf
    install_cilium_cli
    detect_cluster_settings
    install_cilium_cni
    configure_hubble
    verify_cilium_status
    run_connectivity_test
    configure_completion
    print_summary
}

main "$@"
