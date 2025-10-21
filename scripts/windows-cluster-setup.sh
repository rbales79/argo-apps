#!/bin/bash

# OpenShift/Kubernetes Multi-Cluster Management for Windows Git Bash
# This script manages kubeconfigs in the current user's .kube directory and ensures tools are installed

set -e

# Configuration - Get current Windows username
CURRENT_USER=$(whoami | sed 's/.*\\//')  # Remove domain prefix if present
KUBE_DIR="/c/users/$CURRENT_USER/.kube"
TOOLS_DIR="/c/tools"
KUBE_CONFIGS=("kubeconfig-hub" "kubeconfig-test" "kubeconfig-sno")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Emojis (Git Bash compatible)
INFO="[INFO]"
SUCCESS="[OK]"
WARNING="[WARN]"
ERROR="[ERROR]"

print_header() {
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN} OpenShift Cluster Management${NC}"
    echo -e "${CYAN}================================${NC}"
    echo ""
}

print_info() {
    echo -e "${BLUE}${INFO}${NC} $1"
}

print_success() {
    echo -e "${GREEN}${SUCCESS}${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}${WARNING}${NC} $1"
}

print_error() {
    echo -e "${RED}${ERROR}${NC} $1"
}

# Check if running in Git Bash on Windows
check_environment() {
    print_info "Checking environment..."

    if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "cygwin" ]]; then
        print_error "This script is designed for Git Bash on Windows"
        exit 1
    fi

    if [[ ! -d "$KUBE_DIR" ]]; then
        print_error "Kubeconfig directory not found: $KUBE_DIR"
        print_info "Please ensure your kubeconfig files are in C:/users/$CURRENT_USER/.kube/"
        exit 1
    fi

    print_success "Environment check passed"
}

# Create tools directory if it doesn't exist
setup_tools_dir() {
    if [[ ! -d "$TOOLS_DIR" ]]; then
        print_info "Creating tools directory: $TOOLS_DIR"
        mkdir -p "$TOOLS_DIR"

        # Add to PATH in .bashrc if not already there
        if ! grep -q "$TOOLS_DIR" ~/.bashrc 2>/dev/null; then
            echo "" >> ~/.bashrc
            echo "# Add Windows tools directory to PATH" >> ~/.bashrc
            echo "export PATH=\"$TOOLS_DIR:\$PATH\"" >> ~/.bashrc
            print_info "Added $TOOLS_DIR to PATH in ~/.bashrc"
        fi
    fi

    # Add to current session PATH if not there
    if [[ ":$PATH:" != *":$TOOLS_DIR:"* ]]; then
        export PATH="$TOOLS_DIR:$PATH"
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install OpenShift CLI (oc)
install_oc() {
    print_info "Installing OpenShift CLI (oc)..."

    local temp_dir=$(mktemp -d)
    cd "$temp_dir"

    print_info "Downloading OpenShift CLI..."
    curl -sL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-windows.zip -o openshift-client-windows.zip

    print_info "Extracting OpenShift CLI..."
    unzip -q openshift-client-windows.zip

    # Move binaries to tools directory
    mv oc.exe "$TOOLS_DIR/"
    mv kubectl.exe "$TOOLS_DIR/"

    cd - >/dev/null
    rm -rf "$temp_dir"

    print_success "OpenShift CLI installed to $TOOLS_DIR"
}

# Install Helm
install_helm() {
    print_info "Installing Helm..."

    local temp_dir=$(mktemp -d)
    cd "$temp_dir"

    # Get latest Helm version
    print_info "Getting latest Helm version..."
    local helm_version=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep '"tag_name"' | cut -d'"' -f4)

    print_info "Downloading Helm $helm_version..."
    curl -sL "https://get.helm.sh/helm-${helm_version}-windows-amd64.zip" -o helm-windows-amd64.zip

    print_info "Extracting Helm..."
    unzip -q helm-windows-amd64.zip

    # Move binary to tools directory
    mv windows-amd64/helm.exe "$TOOLS_DIR/"

    cd - >/dev/null
    rm -rf "$temp_dir"

    print_success "Helm installed to $TOOLS_DIR"
}

# Check and install required tools
check_and_install_tools() {
    print_info "Checking required tools..."

    # Check OpenShift CLI
    if command_exists oc; then
        local oc_version=$(oc version --client | head -1 2>/dev/null || echo "unknown")
        print_success "OpenShift CLI found: $oc_version"
    else
        print_warning "OpenShift CLI not found, installing..."
        install_oc
    fi

    # Check kubectl (usually comes with oc)
    if command_exists kubectl; then
        local kubectl_version=$(kubectl version --client --output=yaml 2>/dev/null | grep 'gitVersion:' | cut -d':' -f2 | tr -d ' "' || echo "unknown")
        print_success "kubectl found: $kubectl_version"
    else
        print_warning "kubectl not found"
        if command_exists oc; then
            print_info "kubectl should be available with OpenShift CLI"
        fi
    fi

    # Check Helm
    if command_exists helm; then
        local helm_version=$(helm version --short 2>/dev/null || helm version --template='{{.Version}}' 2>/dev/null || echo "unknown")
        print_success "Helm found: $helm_version"
    else
        print_warning "Helm not found, installing..."
        install_helm
    fi
}

# Validate kubeconfig files
check_kubeconfigs() {
    print_info "Checking kubeconfig files..."

    local found_configs=0
    for config in "${KUBE_CONFIGS[@]}"; do
        if [[ -f "$KUBE_DIR/$config" ]]; then
            print_success "Found: $config"
            found_configs=$((found_configs + 1))
        else
            print_warning "Missing: $config"
        fi
    done

    if [[ $found_configs -eq 0 ]]; then
        print_error "No kubeconfig files found in $KUBE_DIR"
        exit 1
    fi

    print_success "Found $found_configs kubeconfig file(s)"
}

# Create cluster management functions for Windows Git Bash
create_cluster_functions() {
    print_info "Setting up cluster management functions..."

    local cluster_script="$HOME/.cluster-functions.sh"

    cat > "$cluster_script" << 'EOF'
#!/bin/bash

# OpenShift/Kubernetes Multi-Cluster Management Functions for Windows Git Bash

# Get current Windows username (handle domain\username format)
CURRENT_USER=$(whoami | sed 's/.*\\//')
KUBE_DIR="/c/users/$CURRENT_USER/.kube"

# Function to switch to hub cluster
use-hub() {
    export KUBECONFIG="$KUBE_DIR/kubeconfig-hub"
    echo "[INFO] Switched to HUB cluster"
    if oc whoami >/dev/null 2>&1; then
        local user=$(oc whoami)
        local nodes=$(oc get nodes --no-headers 2>/dev/null | wc -l)
        echo "[OK] Connected as: $user"
        echo "[INFO] Cluster has $nodes nodes"
        oc get nodes --no-headers | awk '{print "   - " $1 " (" $2 ")"}'
    else
        echo "[WARN] Cannot connect to hub cluster"
    fi
}

# Function to switch to test cluster
use-test() {
    export KUBECONFIG="$KUBE_DIR/kubeconfig-test"
    echo "[INFO] Switched to TEST cluster"
    if oc whoami >/dev/null 2>&1; then
        local user=$(oc whoami)
        local nodes=$(oc get nodes --no-headers 2>/dev/null | wc -l)
        echo "[OK] Connected as: $user"
        echo "[INFO] Cluster has $nodes nodes"
        oc get nodes --no-headers | awk '{print "   - " $1 " (" $2 ")"}'
    else
        echo "[WARN] Cannot connect to test cluster"
    fi
}

# Function to switch to sno cluster
use-sno() {
    export KUBECONFIG="$KUBE_DIR/kubeconfig-sno"
    echo "[INFO] Switched to SNO cluster"
    if oc whoami >/dev/null 2>&1; then
        local user=$(oc whoami)
        local nodes=$(oc get nodes --no-headers 2>/dev/null | wc -l)
        echo "[OK] Connected as: $user"
        echo "[INFO] Cluster has $nodes nodes"
        oc get nodes --no-headers | awk '{print "   - " $1 " (" $2 ")"}'
    else
        echo "[WARN] Cannot connect to sno cluster"
    fi
}

# Function to show current cluster context
current-cluster() {
    if [ -z "$KUBECONFIG" ]; then
        echo "[ERROR] No cluster selected"
        echo "[INFO] Use 'hub', 'test', or 'sno' to connect to a cluster"
        return 1
    fi

    local cluster_name=$(basename "$KUBECONFIG" | sed 's/kubeconfig-//')
    echo "[INFO] Current cluster: $cluster_name"
    echo "[INFO] Kubeconfig: $KUBECONFIG"

    if oc whoami >/dev/null 2>&1; then
        echo "[INFO] User: $(oc whoami)"
        echo "[INFO] Context: $(oc config current-context 2>/dev/null || echo 'default')"
        echo "[INFO] Nodes:"
        oc get nodes
    else
        echo "[ERROR] Not connected or not authenticated"
    fi
}

# Quick cluster status
cluster-status() {
    echo "[INFO] Available clusters:"

    local original_kubeconfig="$KUBECONFIG"

    for config in "$KUBE_DIR"/kubeconfig-*; do
        if [ -f "$config" ]; then
            local name=$(basename "$config" | sed 's/kubeconfig-//')
            local current=""
            [ "$KUBECONFIG" = "$config" ] && current=" (current)"

            export KUBECONFIG="$config"
            if oc whoami >/dev/null 2>&1; then
                local nodes=$(oc get nodes --no-headers 2>/dev/null | wc -l)
                echo "  [OK] $name: $nodes nodes$current"
            else
                echo "  [ERROR] $name: not accessible$current"
            fi
        fi
    done

    # Restore original KUBECONFIG
    export KUBECONFIG="$original_kubeconfig"
}

# Show available clusters on load
show-clusters() {
    echo "[INFO] OpenShift Clusters Available:"

    for config in "$KUBE_DIR"/kubeconfig-*; do
        if [ -f "$config" ]; then
            local name=$(basename "$config" | sed 's/kubeconfig-//')
            echo "  [INFO] $name"
        fi
    done

    echo ""
    echo "[INFO] Quick commands:"
    echo "   hub, test, sno     - Switch between clusters"
    echo "   current            - Show current cluster info"
    echo "   status             - Show all cluster status"
    echo "   clusters           - List kubeconfig files"
    echo ""
}

# Aliases for convenience
alias k='kubectl'
alias kc='kubectl'
alias hub='use-hub'
alias test='use-test'
alias sno='use-sno'
alias current='current-cluster'
alias status='cluster-status'
alias clusters='ls -la "$KUBE_DIR"/kubeconfig-*'

# Show available clusters when this script is sourced
if [ -d "$KUBE_DIR" ] && ls "$KUBE_DIR"/kubeconfig-* >/dev/null 2>&1; then
    show-clusters
else
    echo "[WARN] Kubeconfig files not found in $KUBE_DIR"
fi
EOF

    # Add to .bashrc if not already there
    if ! grep -q ".cluster-functions.sh" ~/.bashrc 2>/dev/null; then
        echo "" >> ~/.bashrc
        echo "# OpenShift Multi-Cluster Management" >> ~/.bashrc
        echo "if [ -f ~/.cluster-functions.sh ]; then" >> ~/.bashrc
        echo "    source ~/.cluster-functions.sh" >> ~/.bashrc
        echo "fi" >> ~/.bashrc
        print_success "Cluster management functions added to ~/.bashrc"
    else
        print_info "Cluster management functions already configured in ~/.bashrc"
    fi

    # Source for current session
    source "$cluster_script"

    print_success "Cluster management functions loaded"
}

# Test cluster connections
test_cluster_connections() {
    print_info "Testing cluster connections..."

    local original_kubeconfig="$KUBECONFIG"
    local connected=0

    for config in "${KUBE_CONFIGS[@]}"; do
        if [[ -f "$KUBE_DIR/$config" ]]; then
            export KUBECONFIG="$KUBE_DIR/$config"
            local cluster_name=$(echo "$config" | sed 's/kubeconfig-//')

            if oc whoami >/dev/null 2>&1; then
                local nodes=$(oc get nodes --no-headers 2>/dev/null | wc -l)
                print_success "$cluster_name: Connected ($nodes nodes)"
                connected=$((connected + 1))
            else
                print_warning "$cluster_name: Not accessible"
            fi
        fi
    done

    # Restore original KUBECONFIG
    export KUBECONFIG="$original_kubeconfig"

    print_info "Connected to $connected cluster(s)"
}

# Main execution
main() {
    print_header

    check_environment
    setup_tools_dir
    check_and_install_tools
    check_kubeconfigs
    create_cluster_functions
    test_cluster_connections

    echo ""
    print_success "Setup complete!"
    echo ""
    echo -e "${CYAN}Available commands:${NC}"
    echo "  hub, test, sno     - Switch between clusters"
    echo "  current            - Show current cluster info"
    echo "  status             - Show all cluster status"
    echo "  k, kc              - kubectl aliases"
    echo ""
    echo -e "${YELLOW}Note: Restart Git Bash or run 'source ~/.bashrc' to load functions${NC}"
}

# Run main function
main "$@"
