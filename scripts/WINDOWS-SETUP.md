# Windows Git Bash Cluster Management Setup

This script sets up OpenShift/Kubernetes cluster management on your Windows desktop using Git Bash.

## 📋 Prerequisites

- **Git Bash** installed on Windows
- **Internet connection** for downloading tools
- **Kubeconfig files** in `C:\users\[username]\.kube\` (script automatically detects current username)
  - `kubeconfig-hub`
  - `kubeconfig-test`
  - `kubeconfig-sno`

## 🚀 Installation

1. **Download the script** to your Windows desktop or any convenient location
2. **Open Git Bash**
3. **Navigate** to where you saved the script
4. **Run the setup**:
   ```bash
   ./windows-cluster-setup.sh
   ```

## 🔧 What the Script Does

### ✅ **Tool Installation**

- Downloads and installs **OpenShift CLI (oc)** for Windows
- Downloads and installs **kubectl** (comes with oc)
- Downloads and installs **Helm** for Windows
- Installs tools to `C:\tools\` and adds to PATH

### ✅ **Kubeconfig Management**

- Validates kubeconfig files in `C:\users\[username]\.kube\`
- Creates cluster switching functions
- Sets up aliases and shortcuts

### ✅ **Environment Setup**

- Adds cluster management functions to `~/.bashrc`
- Creates `~/.cluster-functions.sh` with all management functions
- Sets up proper PATH for tools

## 🎯 Available Commands (After Setup)

### **Cluster Switching**

```bash
hub     # Switch to hub cluster
test    # Switch to test cluster
sno     # Switch to SNO cluster
```

### **Information Commands**

```bash
current   # Show current cluster details
status    # Show all cluster status
clusters  # List kubeconfig files
```

### **Tool Shortcuts**

```bash
k         # Alias for kubectl
kc        # Alias for kubectl
helm      # Helm package manager
```

## 📊 Example Usage

```bash
# Switch to hub cluster
hub
[INFO] Switched to HUB cluster
[OK] Connected as: system:admin
[INFO] Cluster has 3 nodes

# Check current cluster
current
[INFO] Current cluster: hub
[INFO] User: system:admin

# Show all cluster status
status
[INFO] Available clusters:
  [OK] hub: 3 nodes (current)
  [OK] test: 1 nodes
  [OK] sno: 1 nodes

# Use kubectl/oc commands
oc get nodes
k get pods -A
helm list
```

## 📁 File Locations

- **Tools**: `C:\tools\` (oc.exe, kubectl.exe, helm.exe)
- **Kubeconfigs**: `C:\users\[username]\.kube\kubeconfig-*`
- **Functions**: `~/.cluster-functions.sh`
- **Config**: `~/.bashrc` (updated with PATH and functions)

## 🔄 After Installation

1. **Restart Git Bash** or run:

   ```bash
   source ~/.bashrc
   ```

2. **Verify installation**:

   ```bash
   oc version --client
   kubectl version --client
   helm version
   ```

3. **Test cluster access**:
   ```bash
   status
   ```

## 🛠️ Troubleshooting

### **Tools Not Found**

- Make sure `C:\tools` is in your PATH
- Restart Git Bash after installation
- Run: `export PATH="/c/tools:$PATH"`

### **Kubeconfig Issues**

- Verify files exist in `C:\users\[username]\.kube\`
- Check file permissions
- Ensure files are valid YAML

### **Connection Problems**

- Check network connectivity
- Verify cluster endpoints are reachable
- Ensure authentication tokens are valid

## 🆕 Re-running the Script

The script is **idempotent** - you can run it multiple times safely:

- It won't re-download tools if they exist
- It won't duplicate configuration entries
- It will validate and report status

## 🔧 Manual Tool Updates

To update tools later:

```bash
# Remove old versions
rm /c/tools/oc.exe /c/tools/kubectl.exe /c/tools/helm.exe

# Re-run setup script
./windows-cluster-setup.sh
```

## 🎉 Features

- ✅ **Automatic tool installation** (oc, kubectl, helm)
- ✅ **Multi-cluster kubeconfig management**
- ✅ **Visual status indicators**
- ✅ **Git Bash optimized**
- ✅ **Windows path handling**
- ✅ **Persistent configuration**
- ✅ **Idempotent execution**
- ✅ **Connection validation**
