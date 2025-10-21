# Keepalived Operator Troubleshooting Guide

This guide helps diagnose and fix issues with the keepalived-operator managing external IPs for services in OpenShift.

## Architecture Overview

The keepalived-operator uses VRRP (Virtual Router Redundancy Protocol) to manage virtual IPs (external IPs) that can float between cluster nodes. Services annotated with `keepalived-operator.redhat-cop.io/keepalivedgroup` get their external IPs managed by keepalived.

## Common Issues and Solutions

### 1. Check Keepalived Operator Status

First, verify the operator is running:

```bash
# Check operator deployment
oc get deployment -n keepalived-operator keepalived-operator-controller-manager

# Check operator pods
oc get pods -n keepalived-operator

# Check operator logs
oc logs -n keepalived-operator deployment/keepalived-operator-controller-manager -f
```

**Expected:** Operator pod should be Running with 1/1 ready.

### 2. Check KeepalivedGroup Configuration

Verify the KeepalivedGroup resource exists and is configured correctly:

```bash
# List all KeepalivedGroups
oc get keepalivedgroup -n keepalived-operator

# Describe the LAN group
oc get keepalivedgroup -n keepalived-operator lan -o yaml
```

**Expected output:**
```yaml
apiVersion: redhatcop.redhat.io/v1alpha1
kind: KeepalivedGroup
metadata:
  name: lan
  namespace: keepalived-operator
spec:
  image: registry.redhat.io/openshift4/ose-keepalived-ipfailover
  interface: br-ex
  interfaceFromIP: 192.168.1.1  # Your gateway IP
  nodeSelector:
    node-role.kubernetes.io/master: ''
```

**Key fields:**
- `interface`: Network interface (usually `br-ex` for OpenShift)
- `interfaceFromIP`: Gateway IP used to determine which interface to use
- `nodeSelector`: Nodes where keepalived pods run (typically master nodes)

### 3. Check Keepalived Pods on Master Nodes

Keepalived pods should be running on each master node:

```bash
# List keepalived pods
oc get pods -n keepalived-operator -l keepalivedgroup=lan -o wide

# Check logs from keepalived pods
oc logs -n keepalived-operator -l keepalivedgroup=lan --tail=50
```

**Expected:** One keepalived pod per master node, all Running.

### 4. Verify Service Configuration

Check the service that should have the external IP:

```bash
# Get the service
oc get svc -n plex plex -o yaml

# Check for required annotation
oc get svc -n plex plex -o jsonpath='{.metadata.annotations.keepalived-operator\.redhat-cop\.io/keepalivedgroup}'
```

**Required service configuration:**
```yaml
metadata:
  annotations:
    keepalived-operator.redhat-cop.io/keepalivedgroup: "keepalived-operator/lan"
spec:
  type: ClusterIP  # Must be ClusterIP
  externalIPs:
    - 192.168.1.200
```

**Common mistakes:**
- Missing annotation
- Wrong annotation format (must be `"namespace/name"`)
- Service type is LoadBalancer instead of ClusterIP
- External IP conflicts with another service

### 5. Check Network Interface on Nodes

Verify the network interface exists on master nodes:

```bash
# SSH to a master node or use debug pod
oc debug node/<master-node-name>

# Inside the debug pod
chroot /host

# List network interfaces
ip addr show

# Check if br-ex exists and can reach the gateway
ip route show | grep 192.168.1.1

# Check for IP conflicts
arping -I br-ex -c 3 192.168.1.200
```

**Expected:**
- `br-ex` interface exists
- Gateway `192.168.1.1` is reachable via `br-ex`
- No ARP replies for `192.168.1.200` (unless keepalived is already managing it)

### 6. Check IP Conflicts

Ensure the external IP isn't already in use:

```bash
# From your local machine
ping 192.168.1.200

# Check ARP table
arp -a | grep 192.168.1.200

# Scan for the IP
nmap -sn 192.168.1.200
```

**If IP responds but service doesn't work:** IP conflict with another device.

### 7. Verify VRRP Traffic

Keepalived uses VRRP multicast traffic (protocol 112):

```bash
# On a master node
tcpdump -i br-ex vrrp -n

# Should see VRRP advertisements
```

**Expected:** VRRP packets every few seconds.

### 8. Check Firewall Rules

Ensure VRRP traffic isn't blocked:

```bash
# On master nodes
iptables -L -n | grep -i vrrp

# Check if protocol 112 is allowed
iptables -L -n | grep 112
```

**Required:** VRRP (IP protocol 112) must be allowed between master nodes.

### 9. Check Node Selector

Verify master nodes have the correct label:

```bash
# List master nodes
oc get nodes -l node-role.kubernetes.io/master

# If no results, check for control-plane label
oc get nodes -l node-role.kubernetes.io/control-plane
```

**Fix:** If using `control-plane` label, update KeepalivedGroup:
```yaml
spec:
  nodeSelector:
    node-role.kubernetes.io/control-plane: ''
```

### 10. Validate External IP Assignment

Check if the IP is actually assigned to a node:

```bash
# On each master node
ip addr show br-ex | grep 192.168.1.200
```

**Expected:** IP should be assigned to `br-ex` on the active master node.

## Common Error Messages

### "Failed to create keepalived pod"

**Cause:** Image pull error or node selector mismatch.

**Solution:**
1. Verify image exists: `registry.redhat.io/openshift4/ose-keepalived-ipfailover`
2. Check node selector matches your nodes
3. Verify pull secrets exist

### "Interface not found"

**Cause:** `interface` or `interfaceFromIP` doesn't match node configuration.

**Solution:**
1. Verify interface name: `oc debug node/<node> -- chroot /host ip link show`
2. Update KeepalivedGroup with correct interface
3. If using OVN-Kubernetes, interface might be `br-ex` or `ovs-system`

### "IP not responding"

**Cause:** Multiple possible issues.

**Solution:**
1. Check keepalived pods are running
2. Verify no IP conflicts
3. Check firewall rules
4. Verify routing on your network

## Configuration Examples

### Single Network (LAN)

```yaml
network:
  lan:
    defaultGateway: 192.168.1.1
```

This creates one KeepalivedGroup named `lan`.

### Multiple Networks

```yaml
network:
  lan:
    defaultGateway: 192.168.1.1
  dmz:
    defaultGateway: 192.168.10.1
  mgmt:
    defaultGateway: 192.168.100.1
```

This creates three KeepalivedGroups: `lan`, `dmz`, `mgmt`.

### Service Using Keepalived

```yaml
apiVersion: v1
kind: Service
metadata:
  name: plex
  annotations:
    keepalived-operator.redhat-cop.io/keepalivedgroup: "keepalived-operator/lan"
spec:
  type: ClusterIP
  externalIPs:
    - 192.168.1.200
  ports:
    - name: http
      port: 32400
      targetPort: 32400
  selector:
    app: plex
```

## Advanced Troubleshooting

### Enable Debug Logging

Edit the operator deployment to enable debug logs:

```bash
oc set env deployment/keepalived-operator-controller-manager -n keepalived-operator ANSIBLE_VERBOSITY=4
```

### Check Operator Events

```bash
oc get events -n keepalived-operator --sort-by='.lastTimestamp'
```

### Manually Test VRRP

Create a test keepalived configuration:

```bash
# On a master node
cat > /tmp/keepalived.conf <<EOF
vrrp_instance VI_1 {
    state MASTER
    interface br-ex
    virtual_router_id 51
    priority 100
    virtual_ipaddress {
        192.168.1.200
    }
}
EOF

# Run keepalived in foreground
keepalived -n -l -f /tmp/keepalived.conf
```

## Recovery Steps

### Restart Keepalived Pods

```bash
# Delete keepalived pods (they'll be recreated)
oc delete pods -n keepalived-operator -l keepalivedgroup=lan
```

### Restart Operator

```bash
oc rollout restart deployment/keepalived-operator-controller-manager -n keepalived-operator
```

### Recreate KeepalivedGroup

```bash
# Delete and let Argo CD recreate
oc delete keepalivedgroup -n keepalived-operator lan

# Wait for Argo CD to sync
# Or manually recreate via:
oc apply -f charts/infrastructure/keepalived-operator/templates/keepalivedgroups.yaml
```

## Verification Checklist

- [ ] Keepalived operator pod is Running
- [ ] KeepalivedGroup resource exists with correct spec
- [ ] Keepalived pods are running on master nodes (one per master)
- [ ] Service has correct annotation: `keepalived-operator.redhat-cop.io/keepalivedgroup: "keepalived-operator/lan"`
- [ ] Service type is ClusterIP (not LoadBalancer)
- [ ] External IP is defined in service spec
- [ ] No IP conflicts on the network
- [ ] br-ex interface exists on master nodes
- [ ] Gateway is reachable from br-ex
- [ ] VRRP traffic is visible on br-ex
- [ ] Firewall allows VRRP (protocol 112)
- [ ] Master nodes have correct label (master or control-plane)
- [ ] IP is assigned to br-ex on one master node

## Additional Resources

- [Keepalived Operator Documentation](https://github.com/redhat-cop/keepalived-operator)
- [VRRP Protocol RFC 5798](https://tools.ietf.org/html/rfc5798)
- [OpenShift Networking Documentation](https://docs.openshift.com/container-platform/latest/networking/understanding-networking.html)
