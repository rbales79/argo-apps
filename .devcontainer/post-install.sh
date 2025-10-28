#!/usr/bin/env bash
set -eux

# initialize pre-commit
git config --global --add safe.directory /workspaces/argo-apps
# pre-commit install --overwrite

echo "🚀 Setting up OpenShift CLI and cluster management..."

# Install OpenShift CLI (oc) and kubectl if not already present
if ! command -v oc &> /dev/null; then
    echo "📥 Downloading OpenShift CLI..."
    curl -sL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz -o /tmp/openshift-client-linux.tar.gz

    echo "📦 Installing OpenShift CLI..."
    cd /tmp
    tar -xzf openshift-client-linux.tar.gz
    mv oc kubectl /usr/local/bin/
    chmod +x /usr/local/bin/oc /usr/local/bin/kubectl
    rm -f /tmp/openshift-client-linux.tar.gz /tmp/README.md

    echo "✅ OpenShift CLI installed: $(oc version --client | head -1)"
else
    echo "✅ OpenShift CLI already installed: $(oc version --client | head -1)"
fi

# Install Helm if not already present
if ! command -v helm &> /dev/null; then
    echo "📥 Downloading Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o /tmp/get_helm.sh

    echo "📦 Installing Helm..."
    chmod +x /tmp/get_helm.sh
    /tmp/get_helm.sh
    rm -f /tmp/get_helm.sh

    echo "✅ Helm installed: $(helm version --short)"
else
    echo "✅ Helm already installed: $(helm version --short)"
fi

# Set up cluster management functions
echo "⚙️  Setting up cluster management functions..."

# Add cluster management script to bashrc if not already present
if ! grep -q "cluster-management.sh" /root/.bashrc; then
    echo "" >> /root/.bashrc
    echo "# OpenShift Multi-Cluster Management" >> /root/.bashrc
    echo "if [ -f /workspaces/argo-apps/.devcontainer/cluster-management.sh ]; then" >> /root/.bashrc
    echo "    source /workspaces/argo-apps/.devcontainer/cluster-management.sh" >> /root/.bashrc
    echo "fi" >> /root/.bashrc
    echo "✅ Cluster management functions added to .bashrc"
else
    echo "✅ Cluster management functions already configured"
fi

# Source the cluster management script for the current session
if [ -f /workspaces/argo-apps/.devcontainer/cluster-management.sh ]; then
    source /workspaces/argo-apps/.devcontainer/cluster-management.sh
fi

echo "🎉 Setup complete! Multi-cluster management ready."
