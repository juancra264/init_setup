#!/usr/bin/env bash
# ==============================================================================
# Helm 3 Automated Installer for Kubernetes Cluster
# Target OS: Debian / Ubuntu / RedHat / Generic Linux
# ==============================================================================
set -euo pipefail

# --- Default Configuration Variables ---
HELM_VERSION="${HELM_VERSION:-latest}"          # Target Helm version (e.g. v3.16.2 or 'latest')
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"    # Destination directory for the helm binary
KUBECONFIG_PATH="${KUBECONFIG:-}"              # Custom kubeconfig path (auto-detected if empty)
ADD_REPOSITORIES="${ADD_REPOSITORIES:-true}"    # Add recommended Helm chart repositories
SETUP_COMPLETION="${SETUP_COMPLETION:-true}"    # Configure bash shell completion for Helm
SKIP_CLUSTER_CHECK="${SKIP_CLUSTER_CHECK:-false}" # Skip Kubernetes cluster connectivity test

# Fallback stable version if dynamic resolution fails
DEFAULT_FALLBACK_VERSION="v3.16.2"

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
  _    _      _             
 | |  | |    | |            
 | |__| | ___| |_ __ ___    
 |  __  |/ _ \ | '_ ` _ \   
 | |  | |  __/ | | | | | |  
 |_|  |_|\___|_|_| |_| |_|  
 Helm 3 Package Manager Installer for Kubernetes
EOF
    echo -e "${NC}"
}

usage() {
    cat <<EOF
Usage: sudo ./install-helm.sh [OPTIONS]

Options:
  -v, --version <version>       Helm version to install (e.g. v3.16.2 or 'latest', default: latest)
  -d, --dir <path>              Installation directory for binary (default: /usr/local/bin)
  -k, --kubeconfig <path>       Path to kubeconfig file (default: auto-detected)
  --no-repos                    Skip adding popular community chart repositories
  --no-completion               Skip setting up bash shell autocompletion
  --skip-cluster-check          Skip testing Kubernetes cluster connectivity
  -h, --help                    Show this help message

Environment variables can also be used:
  HELM_VERSION, INSTALL_DIR, KUBECONFIG, ADD_REPOSITORIES, SETUP_COMPLETION, SKIP_CLUSTER_CHECK

Examples:
  sudo ./install-helm.sh
  sudo ./install-helm.sh --version v3.16.2
  sudo ./install-helm.sh --no-repos
  sudo ./install-helm.sh --kubeconfig /etc/kubernetes/admin.conf
EOF
    exit 0
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--version)
                HELM_VERSION="$2"
                shift 2
                ;;
            -d|--dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            -k|--kubeconfig)
                KUBECONFIG_PATH="$2"
                shift 2
                ;;
            --no-repos)
                ADD_REPOSITORIES="false"
                shift 1
                ;;
            --no-completion)
                SETUP_COMPLETION="false"
                shift 1
                ;;
            --skip-cluster-check)
                SKIP_CLUSTER_CHECK="true"
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

    # Check write permissions on target installation directory
    if [[ ! -w "$INSTALL_DIR" ]]; then
        if [[ $EUID -ne 0 ]]; then
            log_error "Target directory '$INSTALL_DIR' is not writable. Please run with sudo or as root."
            exit 1
        fi
    fi

    # Detect OS
    OS_TYPE="$(uname -s | tr '[:upper:]' '[:lower:]')"
    if [[ "$OS_TYPE" != "linux" ]]; then
        log_warn "Detected OS is '$OS_TYPE'. This script is optimized for Linux."
    else
        log_info "Operating System: Linux"
    fi

    # Detect Architecture
    local raw_arch
    raw_arch="$(uname -m)"
    case "$raw_arch" in
        x86_64|amd64)
            TARGET_ARCH="amd64"
            ;;
        aarch64|arm64)
            TARGET_ARCH="arm64"
            ;;
        armv7*|armhf)
            TARGET_ARCH="arm"
            ;;
        ppc64le)
            TARGET_ARCH="ppc64le"
            ;;
        s390x)
            TARGET_ARCH="s390x"
            ;;
        *)
            log_error "Unsupported CPU architecture: $raw_arch"
            exit 1
            ;;
    esac
    log_info "Detected Architecture: $raw_arch (target: $TARGET_ARCH)"

    # Resolve target version if 'latest'
    if [[ "$HELM_VERSION" == "latest" || -z "$HELM_VERSION" ]]; then
        log_info "Resolving latest stable Helm release..."
        local resolved_version=""

        if command -v curl >/dev/null 2>&1; then
            resolved_version=$(curl -sSfL "https://api.github.com/repos/helm/helm/releases/latest" 2>/dev/null \
                | grep '"tag_name":' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)
            
            if [[ -z "$resolved_version" ]]; then
                # Fallback to redirect resolution
                resolved_version=$(curl -sSfIL -o /dev/null -w '%{url_effective}' "https://github.com/helm/helm/releases/latest" 2>/dev/null \
                    | awk -F'/' '{print $NF}' || true)
            fi
        fi

        if [[ -n "$resolved_version" && "$resolved_version" =~ ^v[0-9]+\.[0-9]+ ]]; then
            HELM_VERSION="$resolved_version"
        else
            log_warn "Could not query latest release tag from GitHub. Falling back to default: $DEFAULT_FALLBACK_VERSION"
            HELM_VERSION="$DEFAULT_FALLBACK_VERSION"
        fi
    fi

    # Ensure version prefix has 'v'
    if [[ ! "$HELM_VERSION" =~ ^v ]]; then
        HELM_VERSION="v${HELM_VERSION}"
    fi

    log_info "Target Helm Version: $HELM_VERSION"
    log_info "Target Binary Directory: $INSTALL_DIR"
}

# --- Step 2: Ensure Prerequisites are Installed ---
install_prerequisites() {
    log_info "Checking prerequisite tools (curl, tar, gzip, ca-certificates)..."
    local missing_tools=()

    for cmd in curl tar gzip sha256sum; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_tools+=("$cmd")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_info "Missing dependencies: ${missing_tools[*]}"
        if [[ $EUID -eq 0 ]] && command -v apt-get >/dev/null 2>&1; then
            log_info "Installing missing dependencies via apt-get..."
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -y
            apt-get install -y --no-install-recommends curl tar gzip ca-certificates coreutils
            log_success "Prerequisites installed."
        elif [[ $EUID -eq 0 ]] && command -v dnf >/dev/null 2>&1; then
            dnf install -y curl tar gzip ca-certificates coreutils
        else
            log_error "Please install the missing tools manually: ${missing_tools[*]}"
            exit 1
        fi
    else
        log_info "All prerequisite tools are available."
    fi
}

# --- Step 3: Download & Install Helm Binary ---
install_helm_binary() {
    log_info "Preparing to download Helm ${HELM_VERSION} (${TARGET_ARCH})..."

    # Create temporary scratch directory
    TMP_DIR="$(mktemp -d -t helm-install-XXXXXX)"
    trap 'rm -rf "$TMP_DIR"' EXIT

    local tarball_name="helm-${HELM_VERSION}-linux-${TARGET_ARCH}.tar.gz"
    local download_url="https://get.helm.sh/${tarball_name}"
    local checksum_url="https://get.helm.sh/${tarball_name}.sha256sum"

    log_info "Downloading: $download_url"
    if ! curl -sSfL "$download_url" -o "${TMP_DIR}/${tarball_name}"; then
        log_error "Failed to download Helm from $download_url"
        exit 1
    fi

    log_info "Downloading checksum: $checksum_url"
    if curl -sSfL "$checksum_url" -o "${TMP_DIR}/${tarball_name}.sha256sum" 2>/dev/null; then
        log_info "Verifying SHA256 checksum..."
        local expected_hash actual_hash
        expected_hash="$(awk '{print $1}' "${TMP_DIR}/${tarball_name}.sha256sum" | tr -d '[:space:]')"
        actual_hash="$(sha256sum "${TMP_DIR}/${tarball_name}" | awk '{print $1}' | tr -d '[:space:]')"

        if [[ "$expected_hash" != "$actual_hash" ]]; then
            log_error "Checksum verification failed!"
            log_error "Expected: $expected_hash"
            log_error "Actual:   $actual_hash"
            exit 1
        fi
        log_success "Checksum verified successfully ($actual_hash)."
    else
        log_warn "Checksum file not available on server; skipping checksum validation."
    fi

    log_info "Extracting binary..."
    tar -zxvf "${TMP_DIR}/${tarball_name}" -C "$TMP_DIR" >/dev/null

    mkdir -p "$INSTALL_DIR"
    local extracted_binary="${TMP_DIR}/linux-${TARGET_ARCH}/helm"

    if [[ ! -f "$extracted_binary" ]]; then
        log_error "Extracted binary not found at $extracted_binary"
        exit 1
    fi

    log_info "Installing Helm binary to ${INSTALL_DIR}/helm..."
    install -m 755 "$extracted_binary" "${INSTALL_DIR}/helm"

    # Verify binary execution
    if ! "${INSTALL_DIR}/helm" version --short >/dev/null 2>&1; then
        log_error "Helm binary was installed, but failed execution check."
        exit 1
    fi

    local installed_ver
    installed_ver="$("${INSTALL_DIR}/helm" version --template='{{.Version}}')"
    log_success "Helm binary installed successfully: ${installed_ver} at ${INSTALL_DIR}/helm"
}

# --- Step 4: Configure Shell Autocompletion ---
configure_completion() {
    if [[ "$SETUP_COMPLETION" != "true" ]]; then
        log_info "Skipping shell autocompletion setup (--no-completion specified)."
        return 0
    fi

    log_info "Configuring bash shell autocompletion for Helm..."

    # System-wide bash completion directory
    local completion_dir="/etc/bash_completion.d"
    if [[ -d "$completion_dir" && -w "$completion_dir" ]]; then
        "${INSTALL_DIR}/helm" completion bash > "${completion_dir}/helm"
        chmod 644 "${completion_dir}/helm"
        log_success "Helm bash completion installed to ${completion_dir}/helm"
    elif [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        local user_home
        user_home="$(eval echo "~${SUDO_USER}")"
        local user_bashrc="${user_home}/.bashrc"
        if [[ -f "$user_bashrc" ]] && ! grep -q "helm completion bash" "$user_bashrc"; then
            echo "" >> "$user_bashrc"
            echo "# Helm bash completion" >> "$user_bashrc"
            echo "source <(helm completion bash)" >> "$user_bashrc"
            chown "${SUDO_USER}:" "$user_bashrc"
            log_success "Helm bash completion added to ${user_bashrc}"
        fi
    fi
}

# --- Step 5: Configure Chart Repositories ---
configure_repositories() {
    if [[ "$ADD_REPOSITORIES" != "true" ]]; then
        log_info "Skipping Helm chart repository setup (--no-repos specified)."
        return 0
    fi

    log_info "Configuring essential Kubernetes Helm chart repositories..."

    # Repositories to add: name -> URL
    declare -A repos=(
        ["bitnami"]="https://charts.bitnami.com/bitnami"
        ["ingress-nginx"]="https://kubernetes.github.io/ingress-nginx"
        ["jetstack"]="https://charts.jetstack.io"
        ["prometheus-community"]="https://prometheus-community.github.io/helm-charts"
    )

    # Function to add repos for a specific user execution context
    add_repos_for_user() {
        local exec_cmd="$1"
        for name in "${!repos[@]}"; do
            local url="${repos[$name]}"
            log_info "Adding repository: $name -> $url"
            eval "$exec_cmd repo add \"$name\" \"$url\" --force-update >/dev/null 2>&1" || true
        done
        eval "$exec_cmd repo update >/dev/null 2>&1" || true
    }

    # Add for current user
    add_repos_for_user "${INSTALL_DIR}/helm"

    # If running with sudo, also add for the invoking non-root user
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        log_info "Configuring repositories for user '${SUDO_USER}'..."
        add_repos_for_user "sudo -u \"${SUDO_USER}\" -H \"${INSTALL_DIR}/helm\""
    fi

    log_success "Default Helm chart repositories configured and updated."
}

# --- Step 6: Cluster Connectivity & Verification ---
verify_cluster_connection() {
    if [[ "$SKIP_CLUSTER_CHECK" == "true" ]]; then
        log_info "Skipping cluster connectivity verification (--skip-cluster-check specified)."
        return 0
    fi

    log_info "Checking Kubernetes cluster connection..."

    # Locate kubeconfig
    local resolved_kubeconfig=""
    if [[ -n "$KUBECONFIG_PATH" && -f "$KUBECONFIG_PATH" ]]; then
        resolved_kubeconfig="$KUBECONFIG_PATH"
    elif [[ -n "${KUBECONFIG:-}" && -f "$KUBECONFIG" ]]; then
        resolved_kubeconfig="$KUBECONFIG"
    elif [[ -f "/etc/kubernetes/admin.conf" ]]; then
        resolved_kubeconfig="/etc/kubernetes/admin.conf"
    elif [[ -f "${HOME}/.kube/config" ]]; then
        resolved_kubeconfig="${HOME}/.kube/config"
    elif [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        local user_home
        user_home="$(eval echo "~${SUDO_USER}")"
        if [[ -f "${user_home}/.kube/config" ]]; then
            resolved_kubeconfig="${user_home}/.kube/config"
        fi
    fi

    if [[ -n "$resolved_kubeconfig" ]]; then
        export KUBECONFIG="$resolved_kubeconfig"
        log_info "Using Kubeconfig: $resolved_kubeconfig"
    else
        log_warn "No kubeconfig file automatically discovered."
        log_warn "Helm requires a valid kubeconfig to communicate with your Kubernetes cluster."
        log_warn "You can configure it via: export KUBECONFIG=/path/to/kubeconfig"
        return 0
    fi

    # Check kubectl if available
    if command -v kubectl >/dev/null 2>&1; then
        if kubectl cluster-info >/dev/null 2>&1; then
            local server_ver
            server_ver="$(kubectl version --output=json 2>/dev/null | grep -Po '"gitVersion":\s*"\K[^"]+' | tail -n 1 || echo "reachable")"
            log_success "Kubernetes API Server is reachable (Kubernetes version: ${server_ver})."
        else
            log_warn "Kubectl could not contact Kubernetes API server. Check your cluster status or kubeconfig."
            return 0
        fi
    fi

    # Verify Helm can interact with the cluster
    log_info "Testing Helm release listing on the cluster..."
    if "${INSTALL_DIR}/helm" list -A >/dev/null 2>&1; then
        log_success "Helm successfully communicated with the Kubernetes cluster!"
    else
        log_warn "Helm binary installed, but was unable to list releases on the cluster."
        log_warn "Ensure your active user or ServiceAccount has appropriate cluster RBAC permissions."
    fi
}

# --- Step 7: Summary & Instructions ---
print_summary() {
    local helm_bin="${INSTALL_DIR}/helm"
    local helm_version_str
    helm_version_str="$("$helm_bin" version --template='{{.Version}}' 2>/dev/null || echo "$HELM_VERSION")"

    echo ""
    echo -e "${GREEN}${BOLD}==============================================================================${NC}"
    echo -e "${GREEN}${BOLD}          Helm 3 Installation Completed Successfully!                         ${NC}"
    echo -e "${GREEN}${BOLD}==============================================================================${NC}"
    echo ""
    echo -e "${BOLD}Helm Installation Details:${NC}"
    echo "  - Version:       $helm_version_str"
    echo "  - Binary Path:   $helm_bin"
    echo ""
    if [[ "$ADD_REPOSITORIES" == "true" ]]; then
        echo -e "${BOLD}Installed Repositories:${NC}"
        "$helm_bin" repo list 2>/dev/null || echo "  (Run 'helm repo list' to inspect)"
        echo ""
    fi
    echo -e "${BOLD}Useful Helm Commands:${NC}"
    echo "  - Search charts:      helm search repo <keyword>"
    echo "  - Update repo cache:  helm repo update"
    echo "  - List releases:      helm list -A"
    echo "  - Install chart:      helm install <release-name> <repo-name>/<chart-name> [flags]"
    echo "  - Upgrade chart:      helm upgrade --install <release-name> <repo-name>/<chart-name>"
    echo "  - Uninstall release:  helm uninstall <release-name> -n <namespace>"
    echo ""
    echo -e "${BOLD}Example Test Deployment (Nginx Ingress Controller):${NC}"
    echo "  helm repo update"
    echo "  helm install ingress-nginx ingress-nginx/ingress-nginx --create-namespace -n ingress-nginx"
    echo ""
}

# --- Main Entry Point ---
main() {
    print_banner
    parse_arguments "$@"
    preflight_checks
    install_prerequisites
    install_helm_binary
    configure_completion
    configure_repositories
    verify_cluster_connection
    print_summary
}

main "$@"
