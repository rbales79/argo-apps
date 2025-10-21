# NFS Troubleshooting Guide for OpenShift

This guide helps diagnose and fix NFS mount issues in your OpenShift cluster.

## Common NFS Mount Errors

### Error: "No such file or directory"
```
mount.nfs: mounting truenas.roybales.com:/volume1/media failed, reason given by server: No such file or directory
```

**Causes:**
- The NFS export path doesn't exist on the server
- The path is not exported/shared
- Incorrect path specified

**Solutions:**
1. Verify the path exists on the NFS server
2. Check NFS exports on the server
3. Ensure the path is correctly configured

---

## Step-by-Step Troubleshooting

### 1. Verify NFS Server Configuration

**On the NFS server (TrueNAS/NAS):**

```bash
# Check if NFS service is running
systemctl status nfs-server

# List all NFS exports
exportfs -v
# or on TrueNAS: cat /etc/exports

# Verify the specific path exists
ls -la /volume1/media

# Check NFS share permissions
# On TrueNAS: System -> Services -> NFS -> Edit
# Ensure:
# - Maproot User: root
# - Maproot Group: wheel (or root)
# - Network: Allow your cluster nodes' network
```

### 2. Test NFS Mount from a Cluster Node

**SSH into any OpenShift worker node:**

```bash
# Test mount manually
mkdir -p /mnt/nfs-test
mount -t nfs -o nfsvers=4.1 truenas.roybales.com:/mnt/volume1/media/media /mnt/nfs-test

# If successful, check contents
ls -la /mnt/nfs-test

# Unmount when done
umount /mnt/nfs-test
rmdir /mnt/nfs-test
```

**Common mount errors and fixes:**

- **Connection refused**: NFS service not running or firewall blocking
- **Permission denied**: Export doesn't allow your cluster network
- **No such file or directory**: Path doesn't exist or isn't exported
- **Timeout**: Network connectivity issue or NFS server unreachable

### 3. Verify Network Connectivity

```bash
# From any cluster node, test connectivity
ping truenas.roybales.com

# Check DNS resolution
nslookup truenas.roybales.com

# Test NFS ports (should be open)
nc -zv truenas.roybales.com 2049  # NFSv4
nc -zv truenas.roybales.com 111   # rpcbind

# Check if server is responding to NFS
showmount -e truenas.roybales.com
```

### 4. Check Kubernetes PV/PVC Status

```bash
# List all PersistentVolumes
oc get pv

# List PersistentVolumeClaims in a namespace
oc get pvc -n overseerr

# Describe a specific PVC to see events
oc describe pvc overseerr-data -n overseerr

# Check PV details
oc describe pv <pv-name>
```

**Look for these status indicators:**
- **Bound**: PV successfully bound to PVC ✅
- **Pending**: Waiting for PV to be created or bound
- **Failed**: Mount failed - check events

### 5. Check Pod Mount Status

```bash
# Get pod status
oc get pods -n overseerr

# Describe pod to see mount errors
oc describe pod <pod-name> -n overseerr

# Check pod events specifically
oc get events -n overseerr --sort-by='.lastTimestamp'

# View pod logs (if it started)
oc logs <pod-name> -n overseerr
```

**Common pod errors:**
- `MountVolume.SetUp failed`: Volume mount failed - check NFS server
- `Back-off restarting failed container`: Application issue, not mount
- `CreateContainerConfigError`: Configuration issue with volumes

### 6. Verify NFS Volume Configuration in Helm

**Check the volume definition:**

```bash
# View the actual volume configuration
oc get pod <pod-name> -n overseerr -o yaml | grep -A 20 volumes:

# Check what's being mounted
oc get pod <pod-name> -n overseerr -o yaml | grep -A 10 volumeMounts:
```

**Verify values are being passed correctly:**

```bash
# Check what values the chart is using
helm get values <release-name> -n <namespace>

# Template the chart locally to see rendered values
cd charts/media/overseerr
helm template . --values values.yaml --set cluster.storage.media.nfs.server=truenas.roybales.com
```

### 7. Debug with a Test Pod

Create a simple pod to test NFS mounting:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nfs-test-pod
  namespace: default
spec:
  containers:
  - name: test
    image: busybox
    command: ['sh', '-c', 'echo "Testing NFS" && ls -la /mnt/nfs && sleep 3600']
    volumeMounts:
    - name: nfs-volume
      mountPath: /mnt/nfs
  volumes:
  - name: nfs-volume
    nfs:
      server: truenas.roybales.com
      path: /volume1/media
```

**Deploy and check:**

```bash
# Create the test pod
oc apply -f nfs-test-pod.yaml

# Check if it's running
oc get pod nfs-test-pod

# View logs
oc logs nfs-test-pod

# Exec into pod to test
oc exec -it nfs-test-pod -- sh
ls -la /mnt/nfs
touch /mnt/nfs/test-file.txt
ls -la /mnt/nfs/test-file.txt

# Clean up
oc delete pod nfs-test-pod
```

---

## Configuration Verification Checklist

### ✅ NFS Server Side

- [ ] NFS service is running
- [ ] Path `/volume1/media` exists
- [ ] Path is exported (check `/etc/exports`)
- [ ] Export allows cluster network (e.g., `192.168.1.0/24`)
- [ ] Permissions: maproot=root or appropriate user
- [ ] Firewall allows NFS ports (2049, 111)

### ✅ OpenShift Side

- [ ] DNS resolves `truenas.roybales.com` correctly
- [ ] Network connectivity to NFS server (ping works)
- [ ] NFS ports accessible (port 2049, 111)
- [ ] Cluster values have correct NFS server and path
- [ ] PV/PVC are in "Bound" state
- [ ] Pod events show no mount errors

### ✅ Configuration Values

Check `clusters/hub/values.yaml` or `clusters/media/values.yaml`:

```yaml
config:
  cluster:
    storage:
      media:
        nfs:
          server: truenas.roybales.com  # Correct server
          path: /volume1/media           # Correct path
```

---

## Common Issues and Solutions

### Issue 1: "No such file or directory"

**Cause**: Path doesn't exist or isn't exported

**Fix**:
1. Create the path on NFS server: `mkdir -p /volume1/media`
2. Add to NFS exports (TrueNAS: Sharing → Unix Shares (NFS))
3. Restart NFS service: `systemctl restart nfs-server`
4. Verify: `showmount -e truenas.roybales.com`

### Issue 2: "Permission denied"

**Cause**: NFS export doesn't allow the cluster network or wrong permissions

**Fix**:
1. Update NFS export to allow cluster network
   ```
   /volume1/media 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
   ```
2. Set maproot to root in TrueNAS
3. Check directory permissions: `chmod 755 /volume1/media`

### Issue 3: "Connection timed out"

**Cause**: Firewall blocking or NFS service not running

**Fix**:
1. Check NFS service: `systemctl status nfs-server`
2. Check firewall rules
3. Verify network connectivity: `ping truenas.roybales.com`
4. Test NFS port: `nc -zv truenas.roybales.com 2049`

### Issue 4: "Stale file handle"

**Cause**: NFS export was changed/deleted while mounted

**Fix**:
1. Delete the pod: `oc delete pod <pod-name> -n <namespace>`
2. Re-export the share on NFS server
3. Pod will be recreated with fresh mount by Argo CD

### Issue 5: "Read-only file system"

**Cause**: NFS export is read-only or mount option is ro

**Fix**:
1. Check NFS export has `rw` option
2. Verify mount options in volume definition
3. Check TrueNAS share permissions (Read/Write)

### Issue 6: DNS Resolution Issues

**Cause**: `truenas.roybales.com` doesn't resolve

**Fix**:
1. Add to cluster DNS or use IP address directly
2. Update values to use IP: `server: 192.168.1.x`
3. Check CoreDNS configuration: `oc get configmap coredns -n openshift-dns -o yaml`

---

## Quick Diagnostic Commands

```bash
# One-liner to check NFS mount issues
oc get events --all-namespaces --sort-by='.lastTimestamp' | grep -i "mount\|nfs\|volume"

# Check all PVCs with mount issues
oc get pvc --all-namespaces | grep -v Bound

# Find pods with mount errors
oc get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded

# View all NFS-related configuration
oc get pv -o custom-columns=NAME:.metadata.name,NFS-SERVER:.spec.nfs.server,NFS-PATH:.spec.nfs.path

# Quick test if NFS is accessible from any pod
oc run nfs-test --rm -it --image=busybox -- sh -c "mount -t nfs truenas.roybales.com:/volume1/media /mnt && ls /mnt"
```

---

## Advanced: NFS Performance Tuning

If mounts work but performance is slow:

```yaml
# Recommended NFS mount options in volume spec
nfs:
  server: truenas.roybales.com
  path: /mnt/volume1/media
  # Add these to PV spec if needed:
  mountOptions:
    - nfsvers=4.1
    - hard
    - nconnect=8       # Multiple TCP connections
    - rsize=131072     # Read buffer size
    - wsize=131072     # Write buffer size
    - noatime          # Don't update access times
```

---

## Getting Help

If issues persist after following this guide:

1. **Collect diagnostics:**
   ```bash
   # Save all relevant information
   oc describe pod <pod-name> -n <namespace> > pod-describe.txt
   oc get events -n <namespace> --sort-by='.lastTimestamp' > events.txt
   oc get pvc -n <namespace> -o yaml > pvc.yaml
   ```

2. **Check application logs:**
   ```bash
   oc logs <pod-name> -n <namespace>
   ```

3. **Verify cluster values are being applied:**
   ```bash
   # Check rendered Helm values
   oc get application <app-name> -n openshift-gitops -o yaml
   ```

## References

- [Kubernetes NFS Volumes](https://kubernetes.io/docs/concepts/storage/volumes/#nfs)
- [OpenShift Persistent Storage](https://docs.openshift.com/container-platform/latest/storage/understanding-persistent-storage.html)
- [NFS Best Practices](https://docs.openshift.com/container-platform/latest/storage/persistent_storage/persistent-storage-nfs.html)
