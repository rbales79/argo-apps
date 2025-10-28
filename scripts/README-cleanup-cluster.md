# Cluster Cleanup Script

## Overview

This script automates the cleanup of common problematic resources in OpenShift/Kubernetes clusters, specifically targeting issues encountered during GitOps operations.

## Common Problems Solved

1. **Argo CD Applications with Stuck Finalizers**

   - Applications that won't delete due to finalizers
   - Applications stuck in deletion state

2. **Stuck Terminating Namespaces**

   - Namespaces that won't terminate due to remaining resources
   - Pods and PVCs with finalizers preventing deletion
   - Persistent volumes blocking namespace deletion

3. **Kasten K10 Cleanup**

   - Stale API services blocking namespace deletion
   - K10 CRDs preventing clean uninstall
   - K10 custom resources with finalizers

4. **External Secrets Operator Issues**

   - ClusterSecretStore CRs blocking operator upgrades
   - Conversion webhook failures during installation
   - Stale CRDs and API services
   - Failed install plans

5. **Keepalived Operator Resources**

   - Stale CRDs after uninstall

6. **cert-manager Resources**

   - Webhook configurations blocking deletion

7. **Stale API Services**
   - API services with unavailable backends

## Usage

### Run All Cleanup Tasks (Default)

```bash
./scripts/cleanup-cluster.sh
```

### Run Specific Cleanup Tasks

```bash
# Clean up Argo CD applications only
./scripts/cleanup-cluster.sh --argo

# Clean up stuck terminating namespaces only
./scripts/cleanup-cluster.sh --namespaces

# Clean up Kasten K10 resources
./scripts/cleanup-cluster.sh --kasten

# Clean up External Secrets Operator
./scripts/cleanup-cluster.sh --eso

# Clean up multiple specific components
./scripts/cleanup-cluster.sh --argo --namespaces --eso
```

### Available Options

- `--all` - Run all cleanup tasks (default if no options provided)
- `--argo` - Clean up Argo CD applications
- `--namespaces` - Clean up stuck terminating namespaces
- `--kasten` - Clean up Kasten K10 resources
- `--eso` or `--external-secrets` - Clean up External Secrets Operator
- `--keepalived` - Clean up Keepalived Operator
- `--cert-manager` - Clean up cert-manager resources
- `--api-services` - Check and clean stale API services (interactive)
- `--help` or `-h` - Show help message

## What the Script Does

### Argo CD Applications Cleanup

- Removes finalizers from all Argo CD applications in openshift-gitops namespace
- Allows immediate deletion without waiting for resource cleanup

### Stuck Namespaces Cleanup

For each stuck terminating namespace:

- Removes finalizers from all pods
- Removes finalizers from all PVCs
- Removes finalizers from associated PVs
- Reports any remaining resources

### Kasten K10 Cleanup

- Removes Kasten API services (e.g., `v1alpha1.*.kio.kasten.io`)
- Deletes all Kasten CRDs
- Removes finalizers from k10 custom resource
- Allows kasten-io namespace to terminate

### External Secrets Operator Cleanup

- Deletes all ClusterSecretStore CRs
- Removes all ExternalSecret CRs across all namespaces
- Deletes OperatorConfig CRs
- Removes ESO CRDs
- Cleans up ESO API services
- Deletes failed install plans
- Resolves conversion webhook issues during upgrades

### Keepalived Operator Cleanup

- Removes Keepalived CRDs
- Allows keepalived-operator namespace to terminate

### cert-manager Cleanup

- Removes webhook configurations that may block deletion

### Stale API Services

- Identifies API services with unavailable backends (status: False)
- Prompts for confirmation before deletion (interactive)

## Safety Features

- Color-coded output for easy reading
- Informative logging at each step
- Continues on errors (non-blocking failures)
- Interactive confirmation for potentially dangerous operations
- No destructive operations on running applications

## Prerequisites

- `oc` CLI must be installed and configured
- User must be logged into the OpenShift cluster
- User must have cluster-admin or sufficient RBAC permissions

## Example Output

```
[INFO] Starting cluster cleanup...

[INFO] Cleaning up Argo CD applications...
[INFO] Removing finalizers from application.argoproj.io/plex
[INFO] Removing finalizers from application.argoproj.io/radarr
[SUCCESS] Argo CD applications cleaned

[INFO] Cleaning up stuck terminating namespaces...
[WARNING] Found stuck namespace: overseerr
[INFO]   Removing pod finalizers in overseerr...
[INFO]   Removing PVC finalizers in overseerr...
[SUCCESS]   Cleaned overseerr

[SUCCESS] ==========================================
[SUCCESS] Cluster cleanup complete!
[SUCCESS] ==========================================
```

## Common Use Cases

### After Deleting an ApplicationSet

If you delete an Argo CD ApplicationSet and the child applications are stuck:

```bash
./scripts/cleanup-cluster.sh --argo
```

### Before Reinstalling an Operator

To ensure clean reinstallation of External Secrets Operator:

```bash
./scripts/cleanup-cluster.sh --eso
```

### Complete Cluster Reset

To clean up all known problematic resources:

```bash
./scripts/cleanup-cluster.sh
```

### Namespace Won't Delete

If specific namespaces are stuck terminating:

```bash
./scripts/cleanup-cluster.sh --namespaces
```

## Troubleshooting

### Script Hangs or Times Out

- Press Ctrl+C to stop
- Check if cluster API is responsive: `oc get nodes`
- Try running specific cleanup tasks instead of --all

### Permission Denied Errors

- Ensure you're logged in: `oc whoami`
- Verify cluster-admin access: `oc auth can-i '*' '*'`

### Resources Still Stuck After Cleanup

- Run the script again (some resources may need multiple passes)
- Check for additional finalizers: `oc get <resource> -o yaml | grep finalizers`
- Manually patch remaining resources: `oc patch <resource> --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]'`

## Related Documentation

- [Keepalived Troubleshooting](../docs/keepalived-troubleshooting.md)
- [TrueNAS CSI Troubleshooting](../docs/truenas-csi-troubleshooting.md)
- [NFS Troubleshooting](../docs/nfs-troubleshooting.md)

## Contributing

If you encounter a new class of stuck resources, please:

1. Document the issue
2. Add a cleanup function to the script
3. Add a command-line option for the new cleanup task
4. Update this README
