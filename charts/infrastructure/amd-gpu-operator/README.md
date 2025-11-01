# AMD GPU Operator

Helm chart for deploying the AMD GPU Device Plugin on OpenShift/Kubernetes clusters. This enables GPU resource allocation and scheduling for AMD Radeon and Instinct GPUs.

## Overview

This chart deploys the AMD GPU Device Plugin as a DaemonSet on nodes with AMD GPUs. It exposes AMD GPUs as allocatable resources to Kubernetes, allowing workloads to request and use GPU resources.

## Features

- ✅ Automatic GPU discovery and resource advertisement
- ✅ **Automatic node labelling** with GPU properties (model, VRAM, compute units)
- ✅ Support for AMD Radeon and Instinct GPUs
- ✅ ROCm (Radeon Open Compute) platform integration
- ✅ OpenShift SecurityContextConstraints (SCC) support
- ✅ Node selector and toleration support for targeted deployment
- ✅ Configurable resource naming and visibility

## Prerequisites

### 1. AMD GPU Drivers and ROCm

Nodes must have AMD GPU drivers and ROCm installed. For RHEL/RHCOS:

```bash
# Add AMD ROCm repository
sudo tee /etc/yum.repos.d/amdgpu.repo <<EOF
[amdgpu]
name=amdgpu
baseurl=https://repo.radeon.com/amdgpu/latest/rhel/\$releasever/main/x86_64
enabled=1
gpgcheck=1
gpgkey=https://repo.radeon.com/rocm/rocm.gpg.key
EOF

# Install ROCm
sudo dnf install rocm-dkms rocm-dev

# Verify installation
rocminfo
```

### 2. Node Labelling (Automatic or Manual)

#### Option A: Automatic (Recommended)

The chart includes an AMD GPU Node Labeller that automatically discovers GPUs and labels nodes. It's enabled by default and will:

- Detect AMD GPUs on all nodes
- Apply labels with GPU properties (family, VRAM, compute units)
- Automatically add the required `amd.feature.node.kubernetes.io/gpu=true` label

No manual action required when using the node labeller!

#### Option B: Manual Labelling

If you disable the node labeller (`amdNodeLabeller.enabled: false`), manually label nodes:

```bash
kubectl label node <node-name> amd.feature.node.kubernetes.io/gpu=true
```

You can also use Node Feature Discovery (NFD) with custom rules.

## Installation

### Deploy via Argo CD

Add to your cluster's ApplicationSet:

```yaml
- name: amd-gpu-operator
  group: infrastructure
  createNamespace: false
```

### Deploy via Helm

```bash
helm install amd-gpu-operator ./charts/infrastructure/amd-gpu-operator \
  --namespace kube-system
```

## Configuration

### Key Values

#### Device Plugin Configuration

| Parameter                         | Description                         | Default                                      |
| --------------------------------- | ----------------------------------- | -------------------------------------------- |
| `amdGpuPlugin.image.repository`   | Device plugin image                 | `rocm/k8s-device-plugin`                     |
| `amdGpuPlugin.image.tag`          | Image tag                           | `latest`                                     |
| `amdGpuPlugin.resourceName`       | Kubernetes resource name            | `amd.com/gpu`                                |
| `amdGpuPlugin.nodeSelector`       | Node selector for plugin deployment | `amd.feature.node.kubernetes.io/gpu: "true"` |
| `amdGpuPlugin.rocmVisibleDevices` | Which GPUs to expose                | `all`                                        |
| `amdGpuPlugin.logLevel`           | Logging verbosity (0-5)             | `4`                                          |

#### Node Labeller Configuration

**Note:** The AMD ROCm device plugin image does not include a separate node labeller binary. Node labelling must be done manually. The node labeller is disabled by default.

| Parameter                          | Description                           | Default                       |
| ---------------------------------- | ------------------------------------- | ----------------------------- |
| `amdNodeLabeller.enabled`          | Enable automatic node labelling       | `false` (not supported)       |
| `amdNodeLabeller.image.repository` | Node labeller image                   | `rocm/k8s-device-plugin`      |
| `amdNodeLabeller.image.tag`        | Image tag                             | `latest`                      |
| `amdNodeLabeller.nodeSelector`     | Node selector for labeller deployment | `{}` (runs on all nodes)      |
| `amdNodeLabeller.tolerations`      | Tolerations to run on tainted nodes   | `Exists` (runs on all nodes)  |
| `amdNodeLabeller.enabledLabels`    | List of GPU property labels to apply  | See values.yaml for full list |

#### General Configuration

| Parameter   | Description          | Default       |
| ----------- | -------------------- | ------------- |
| `namespace` | Deployment namespace | `kube-system` |

### Example Custom Values

#### Basic Configuration

```yaml
amdGpuPlugin:
  # Use specific GPUs only
  rocmVisibleDevices: "0,1"

  # Add tolerations for dedicated GPU nodes
  tolerations:
    - key: "gpu"
      operator: "Equal"
      value: "amd"
      effect: "NoSchedule"

  # Increase resources for large clusters
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 1Gi
```

#### Manual Node Labelling Required

**The node labeller is not functional** as the ROCm device plugin image doesn't include the labeller binary. Node labelling must be done manually (default configuration):

```yaml
amdNodeLabeller:
  enabled: false # Disabled by default - manual labelling required
```

**To label nodes manually:**

```bash
# Label a node to enable AMD GPU device plugin
kubectl label node <node-name> amd.feature.node.kubernetes.io/gpu=true

# Optional: Add additional GPU information labels
kubectl label node <node-name> \
  amd.com/gpu.family=gfx1030 \
  amd.com/gpu.vram=8GB \
  amd.com/gpu.device-id=73ff
```

**Using Node Feature Discovery (NFD):**

You can also use NFD with custom rules to automatically label nodes with AMD GPUs. See the NFD documentation for PCI device detection rules.

## Usage

### Requesting AMD GPUs in Pods

Once deployed, pods can request AMD GPU resources:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
spec:
  containers:
    - name: rocm-test
      image: rocm/pytorch:latest
      resources:
        limits:
          amd.com/gpu: 1 # Request 1 AMD GPU
```

### Requesting Multiple GPUs

```yaml
resources:
  limits:
    amd.com/gpu: 2 # Request 2 AMD GPUs
```

### Example: ROCm PyTorch Job

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: rocm-pytorch-job
spec:
  template:
    spec:
      containers:
        - name: pytorch
          image: rocm/pytorch:latest
          command:
            - python3
            - -c
            - |
              import torch
              print(f"CUDA Available: {torch.cuda.is_available()}")
              print(f"GPU Count: {torch.cuda.device_count()}")
              if torch.cuda.is_available():
                  print(f"GPU Name: {torch.cuda.get_device_name(0)}")
          resources:
            limits:
              amd.com/gpu: 1
      restartPolicy: Never
```

### Node Selector Based on GPU Properties

With the node labeller enabled, you can schedule workloads based on specific GPU characteristics:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-specific-workload
spec:
  nodeSelector:
    amd.com/gpu.family: "gfx1030" # Target specific GPU architecture
    amd.com/gpu.vram: "8192" # Require 8GB VRAM
  containers:
    - name: workload
      image: rocm/pytorch:latest
      resources:
        limits:
          amd.com/gpu: 1
```

## Node Labeller Details

The AMD GPU Node Labeller automatically discovers AMD GPUs and applies descriptive labels to nodes.

### Applied Labels

When enabled, the node labeller adds the following labels:

| Label                                | Description                           | Example Value |
| ------------------------------------ | ------------------------------------- | ------------- |
| `amd.feature.node.kubernetes.io/gpu` | Indicates node has AMD GPU (required) | `true`        |
| `amd.com/gpu.family`                 | GPU architecture family               | `gfx1030`     |
| `amd.com/gpu.vram`                   | GPU VRAM in MB                        | `8192`        |
| `amd.com/gpu.cu-count`               | Number of compute units               | `36`          |
| `amd.com/gpu.simd-count`             | Number of SIMD units                  | `144`         |
| `amd.com/gpu.device-id`              | PCI device ID                         | `73ff`        |

### How It Works

1. **Discovery**: Labeller DaemonSet runs on all nodes with `Exists` toleration
2. **Detection**: Scans `/dev/dri` and `/sys` for AMD GPU devices
3. **Labelling**: Uses ROCm APIs to query GPU properties
4. **Application**: Updates node labels via Kubernetes API
5. **Device Plugin Trigger**: Once labelled, device plugin DaemonSet deploys to GPU nodes

## Verification

### 1. Check DaemonSet Deployments

```bash
# Check device plugin DaemonSet
kubectl get daemonset -n kube-system amd-gpu-device-plugin
kubectl get pods -n kube-system -l app.kubernetes.io/name=amd-gpu-device-plugin

# Check node labeller DaemonSet
kubectl get daemonset -n kube-system amd-gpu-node-labeller
kubectl get pods -n kube-system -l app.kubernetes.io/name=amd-gpu-node-labeller
```

### 2. Verify Node Labels

```bash
# Check if nodes have GPU labels
kubectl get nodes --show-labels | grep amd.feature.node.kubernetes.io/gpu

# View all AMD GPU labels on a specific node
kubectl get node <node-name> -o json | jq '.metadata.labels | with_entries(select(.key | startswith("amd.")))'
```

### 3. Verify GPU Resources on Nodes

```bash
kubectl describe node <node-with-gpu> | grep amd.com/gpu
```

Expected output:

```text
amd.com/gpu:  1
```

### 4. Check Logs

```bash
# Device plugin logs
kubectl logs -n kube-system -l app.kubernetes.io/name=amd-gpu-device-plugin

# Node labeller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=amd-gpu-node-labeller
```

### 5. Verify End-to-End

Create a test pod to verify GPU allocation works:

````bash
kubectl run gpu-test --image=rocm/rocm-terminal --rm -it --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"gpu-test","image":"rocm/rocm-terminal","command":["rocminfo"],"resources":{"limits":{"amd.com/gpu":"1"}}}]}}' \

```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=amd-gpu-device-plugin
````

## Troubleshooting

### Device Plugin Not Starting

**Check node labels:**

```bash
kubectl get nodes --show-labels | grep amd.feature.node.kubernetes.io/gpu
```

**Check ROCm installation on node:**

```bash
ssh <node> rocminfo
```

### GPUs Not Showing in Node Capacity

**Check device plugin logs:**

```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=amd-gpu-device-plugin
```

**Verify /dev/dri and /dev/kfd exist:**

```bash
ssh <node> "ls -la /dev/dri /dev/kfd"
```

### Permission Denied Errors

The device plugin requires privileged access. Verify the SecurityContextConstraints:

```bash
oc get scc amd-gpu-device-plugin
```

## Compatibility

- **OpenShift**: 4.12+
- **Kubernetes**: 1.22+
- **AMD GPUs**: Radeon RX/Pro series, Instinct MI series
- **ROCm**: 5.0+

## Supported AMD GPUs

### Consumer/Workstation

- Radeon RX 6000 series (RDNA 2)
- Radeon RX 7000 series (RDNA 3)
- Radeon Pro series

### Data Center

- Instinct MI50
- Instinct MI100
- Instinct MI200 series
- Instinct MI300 series

## Architecture

```text
┌─────────────────────────────────────────┐
│           Kubernetes Scheduler          │
│    (Allocates amd.com/gpu resources)    │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│      AMD GPU Device Plugin (DaemonSet)  │
│  - Discovers AMD GPUs via ROCm          │
│  - Registers resources with kubelet     │
│  - Monitors GPU health                  │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│        Node with AMD GPU + ROCm         │
│  /dev/dri/* (render nodes)              │
│  /dev/kfd (compute device)              │
│  ROCm runtime libraries                 │
└─────────────────────────────────────────┘
```

## Related Charts

- **Intel GPU Operator**: For Intel integrated/discrete GPUs
- **OpenShift NFD**: For automatic GPU node labeling
- **Generic Device Plugin**: Alternative for custom device types

## References

- [AMD ROCm Documentation](https://rocmdocs.amd.com/)
- [AMD GPU Device Plugin GitHub](https://github.com/RadeonOpenCompute/k8s-device-plugin)
- [Kubernetes Device Plugins](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/device-plugins/)
- [OpenShift GPU Support](https://docs.openshift.com/container-platform/latest/architecture/nvidia-gpu-architecture-overview.html)
