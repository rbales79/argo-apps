# Dev Container Multi-Cluster Setup

This dev container is configured to provide seamless access to multiple OpenShift clusters.

## Prerequisites

- Ensure you have WSL installed with your kubeconfig files located in `/root/.kube/`
  - sudo mkdir -p /root/.kube
  - sudo ln -snf /mnt/c/users/rbale/onedrive/documents/ocp/kubeconfigs /root/.kube (adjust path as needed)
- Make sure you have Docker and VS Code with the Remote - Containers extension installed

## 🏗️ Automatic Setup

The dev container automatically:

1. **Installs OpenShift CLI** (`oc`) and `kubectl`
2. **Mounts your kubeconfig files** from WSL `/root/.kube/`
3. **Sets up cluster management functions** for easy switching between clusters

## 🎯 Available Clusters

- **🏢 HUB**: Production hub cluster
- **🧪 TEST**: Testing/development cluster
- **📱 SNO**: Single Node OpenShift cluster

## 🚀 Quick Commands

### Cluster Switching

```bash
hub     # Switch to hub cluster
test    # Switch to test cluster
sno     # Switch to SNO cluster
```

### Cluster Information

```bash
current   # Show current cluster details
status    # Show all cluster status
clusters  # List kubeconfig files
```

### Shortcuts

```bash
k         # Alias for kubectl
kc        # Alias for kubectl
```

## 📋 Example Usage

```bash
# Switch to hub cluster and check nodes
hub
oc get nodes

# Switch to test cluster and check projects
test
oc get projects

# Show current cluster info
current

# Check status of all clusters
status
```

## 🔧 Configuration Files

- **`.devcontainer/devcontainer.json`**: Mounts WSL `/root/.kube` to `/root/.kube`
- **`.devcontainer/post-install.sh`**: Installs oc CLI and sets up functions
- **`.devcontainer/cluster-management.sh`**: Contains all cluster management functions

## 🔄 Rebuilding the Container

When you rebuild the dev container, everything is automatically reinstalled and configured. Your kubeconfig files are preserved through the mount.

## 🛠️ Manual Setup (if needed)

If for some reason the automatic setup doesn't work:

```bash
# Source the cluster functions manually
source /workspaces/argo-apps/.devcontainer/cluster-management.sh

# Or check if oc is installed
oc version --client
```

## 📁 File Structure

```
.devcontainer/
├── devcontainer.json           # Container configuration with kube mount
├── post-install.sh             # Automatic setup script
├── cluster-management.sh       # Cluster switching functions
└── README.md                  # This file
```

## 🎉 Features

- ✅ Automatic OpenShift CLI installation
- ✅ Multi-cluster kubeconfig management
- ✅ Easy cluster switching with visual feedback
- ✅ Bash completion and aliases
- ✅ Persistent across container rebuilds
- ✅ Status indicators for all clusters
