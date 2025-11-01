# OpenShift Connectivity Troubleshooting Guide

This guide provides commands to diagnose OpenShift cluster connectivity and health issues using `oc` from the control node.

## Prerequisites

- SSH access to a control plane node (if API is unreachable)
- `oc` CLI tool installed
- Cluster admin credentials

## Basic Connectivity Checks

### 1. Login (Verify Connectivity)

Test if the API server is accessible and authenticate:

```bash
oc login https://api.<cluster-domain>:6443 -u <user>
```

If this fails, the API server may be down or unreachable.

### 2. Check Overall Cluster Health

Verify cluster version and operator status:

```bash
# Check cluster version
oc get clusterversion

# Check all cluster operators
oc get clusteroperators

# Check node status
oc get nodes
```

### 3. Verify Control Plane Components

Check critical control plane pods:

```bash
# API server pods
oc get pods -n openshift-apiserver

# Controller manager pods
oc get pods -n openshift-controller-manager

# etcd pods
oc get pods -n openshift-etcd
```

### 4. Summarized Cluster Status

Quick commands to identify issues:

```bash
# Show only unhealthy cluster operators
oc get co | grep -v 'True.*True.*False'

# Confirm nodes are Ready
oc get nodes -o wide

# Show non-running pods across all namespaces
oc get pods --all-namespaces | grep -v Running
```

### 5. Optional Diagnostics

For deeper investigation:

```bash
# Collect comprehensive diagnostic data
oc adm must-gather

# Get detailed operator information
oc describe clusteroperators

# Check resource usage on nodes
oc adm top nodes
```

## When API Server is Unreachable

If the API is down but you have SSH access to a control plane node, use these commands:

### Check API Server Container

```bash
# List running containers and find kube-apiserver
sudo crictl ps | grep kube-apiserver
```

### Check Kubelet Status

```bash
# Verify kubelet service is running
sudo systemctl status kubelet

# Follow kubelet logs in real-time
journalctl -u kubelet -f
```

### Check Static Pod Manifests

```bash
# Verify static pod manifests exist
ls -la /etc/kubernetes/manifests/

# Check API server manifest
cat /etc/kubernetes/manifests/kube-apiserver-pod.yaml
```

### Check etcd Health

```bash
# Check etcd pods
sudo crictl ps | grep etcd

# etcd logs
sudo crictl logs <etcd-container-id>
```

## Common Issues and Solutions

### API Server Not Responding

**Symptoms:**

- `oc login` times out or refuses connection
- Web console unreachable

**Checks:**

1. SSH to control plane node
2. Check if API server container is running: `sudo crictl ps | grep kube-apiserver`
3. Check kubelet status: `sudo systemctl status kubelet`
4. Review kubelet logs: `journalctl -u kubelet -n 100`

### Cluster Operators Degraded

**Symptoms:**

- `oc get co` shows operators not Available or Degraded

**Checks:**

```bash
# Identify problematic operators
oc get co | grep -v 'True.*True.*False'

# Get details on specific operator
oc describe clusteroperator <operator-name>

# Check operator pods
oc get pods -n openshift-<operator-namespace>
```

### Nodes Not Ready

**Symptoms:**

- `oc get nodes` shows NotReady state

**Checks:**

```bash
# Get detailed node info
oc describe node <node-name>

# Check node conditions
oc get nodes -o json | jq '.items[].status.conditions'

# SSH to node and check kubelet
ssh core@<node-ip>
sudo systemctl status kubelet
journalctl -u kubelet -n 100
```

### Machine Config Changes Causing Reboot

**Symptoms:**

- Cluster unreachable after applying changes
- Nodes may be rebooting

**Checks:**

```bash
# Once cluster is back, check machine config operator
oc get mcp
oc get mcp -o wide

# Check which nodes are updating
oc get nodes -o wide

# Review machine config operator logs
oc logs -n openshift-machine-config-operator -l k8s-app=machine-config-controller
```

## Recovery Steps

### If etcd is Unhealthy

```bash
# Check etcd member health
oc get etcd -o=jsonpath='{range .items[0].status.conditions[?(@.type=="EtcdMembersAvailable")]}{.message}{"\n"}{end}'

# Check etcd pods
oc get pods -n openshift-etcd
```

### If Kubelet is Down

SSH to the affected node:

```bash
# Restart kubelet
sudo systemctl restart kubelet

# Check status
sudo systemctl status kubelet

# Follow logs
journalctl -u kubelet -f
```

### If API Server Container Crashed

SSH to control plane node:

```bash
# Check for crashed containers
sudo crictl ps -a | grep kube-apiserver

# View container logs
sudo crictl logs <container-id>

# Check static pod manifest
sudo cat /etc/kubernetes/manifests/kube-apiserver-pod.yaml
```

## Cluster Status Script

Quick health check script:

```bash
#!/bin/bash
echo "=== Cluster Health Check ==="
echo ""
echo "1. Cluster Version:"
oc get clusterversion
echo ""
echo "2. Unhealthy Operators:"
oc get co | grep -v 'True.*True.*False' || echo "All operators healthy"
echo ""
echo "3. Node Status:"
oc get nodes -o wide
echo ""
echo "4. Non-Running Pods:"
oc get pods --all-namespaces | grep -v Running | head -20
echo ""
echo "5. Control Plane Pods:"
oc get pods -n openshift-apiserver,openshift-controller-manager,openshift-etcd
```

## Additional Resources

- [OpenShift Documentation - Troubleshooting](https://docs.openshift.com/container-platform/latest/support/troubleshooting/investigating-pod-issues.html)
- [OpenShift must-gather](https://docs.openshift.com/container-platform/latest/support/gathering-cluster-data.html)
- [etcd Troubleshooting](https://docs.openshift.com/container-platform/latest/backup_and_restore/control_plane_backup_and_restore/backing-up-etcd.html)

## Notes

- These commands provide control-plane, operator, and node health information without requiring web console access
- Always check cluster operator status first - many issues manifest as degraded operators
- Machine config changes can cause nodes to reboot, resulting in temporary unavailability
- The `must-gather` command is useful for providing comprehensive diagnostics to Red Hat support
