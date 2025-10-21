# TrueNAS Democratic CSI Helm Chart

This Helm chart deploys the Democratic CSI driver configured for TrueNAS iSCSI storage.

## Prerequisites

- OpenShift or Kubernetes cluster
- TrueNAS SCALE or TrueNAS CORE with iSCSI configured
- External Secrets Operator installed
- Infisical (or compatible secrets backend) with `TRUENAS_API_KEY` stored

## Configuration

### Key Values to Customize

All configuration is done through `values.yaml`. The main settings you'll need to customize:

#### 1. Cluster Information

```yaml
cluster:
  name: cluster # Your cluster name
  top_level_domain: roybales.com # Your domain
```

#### 2. TrueNAS Server Configuration

```yaml
cluster:
  storage:
    truenas:
      server:
        host: truenas.roybales.com # Your TrueNAS hostname/IP
        port: 443 # TrueNAS API port (usually 443 for https)
        protocol: https # http or https
        allowInsecure: true # Set to false if using valid SSL certs
```

#### 3. iSCSI Configuration

```yaml
cluster:
  storage:
    truenas:
      iscsi:
        targetPortal: "truenas.roybales.com:3260" # TrueNAS iSCSI portal
        iqnPrefix: "iqn.2005-10.org.freenas.ctl" # iSCSI IQN prefix
```

#### 4. ZFS Dataset Paths

```yaml
cluster:
  storage:
    truenas:
      zfs:
        datasetParentName: "volume1/iscsi/test/vols" # Where volumes are created
        detachedSnapshotsDatasetParentName: "volume1/iscsi/test/snaps" # Where snapshots are stored
        zvolBlocksize: "16K" # Block size for zvols
        zvolCompression: "lz4" # Compression algorithm
```

#### 5. API Key Configuration

```yaml
cluster:
  storage:
    truenas:
      secretKeys:
        apiKey: TRUENAS_API_KEY # Name of the secret key in Infisical
```

## Installation

### Step 1: Create TrueNAS API Key

1. Log into your TrueNAS web interface
2. Go to **System Settings** → **API Keys**
3. Click **Add** to create a new API key
4. Give it a descriptive name (e.g., "kubernetes-csi")
5. Copy the generated API key

### Step 2: Store API Key in Infisical

1. Log into your Infisical instance
2. Navigate to your project
3. Create or update a secret with key: `TRUENAS_API_KEY`
4. Paste the API key value (no quotes, no extra characters)
5. Save the secret

### Step 3: Configure TrueNAS Datasets

Create the ZFS datasets on your TrueNAS system:

```bash
# On TrueNAS, create the parent datasets
zfs create volume1/iscsi
zfs create volume1/iscsi/test
zfs create volume1/iscsi/test/vols
zfs create volume1/iscsi/test/snaps
```

### Step 4: Update values.yaml

Edit the `values.yaml` file to match your environment:

```yaml
cluster:
  name: my-cluster
  top_level_domain: example.com
  storage:
    truenas:
      server:
        host: truenas.example.com
        port: 443
        protocol: https
        allowInsecure: false # Use true for self-signed certs
      iscsi:
        targetPortal: "truenas.example.com:3260"
        iqnPrefix: "iqn.2005-10.org.freenas.ctl"
      zfs:
        datasetParentName: "tank/k8s/vols"
        detachedSnapshotsDatasetParentName: "tank/k8s/snaps"
        zvolBlocksize: "16K"
        zvolCompression: "lz4"
```

### Step 5: Deploy via Argo CD

This chart is typically deployed via Argo CD ApplicationSet. Ensure it's listed in your storage ApplicationSet template.

```yaml
# In cluster/templates/storage.yaml
- name: truenas
```

## Usage

Once deployed, you can create PersistentVolumeClaims using the storage class:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: truenas-iscsi
  resources:
    requests:
      storage: 10Gi
```

## Troubleshooting

### Check ExternalSecret Sync Status

```bash
kubectl get externalsecret democratic-csi-truenas-config -n democratic-csi
kubectl describe externalsecret democratic-csi-truenas-config -n democratic-csi
```

### Verify Secret Content

```bash
# View the secret (API key will be shown)
kubectl get secret democratic-csi-truenas-config -n democratic-csi -o yaml

# View the driver configuration
kubectl get secret democratic-csi-truenas-config -n democratic-csi \
  -o jsonpath='{.data.driver-config-file\.yaml}' | base64 -d
```

### Check CSI Driver Logs

```bash
# Controller logs
kubectl logs -n democratic-csi -l app.kubernetes.io/name=democratic-csi \
  -c democratic-csi-driver --tail=50

# Node driver logs
kubectl logs -n democratic-csi -l app.kubernetes.io/name=democratic-csi \
  -l app.kubernetes.io/component=node -c democratic-csi-driver --tail=50
```

### Run Diagnostic Script

A comprehensive diagnostic script is available:

```bash
/workspaces/openshift/scripts/diagnose-truenas-csi.sh
```

### Common Issues

See the troubleshooting guides:

- `/workspaces/openshift/docs/truenas-csi-quick-fix.md` - Quick fixes for common issues
- `/workspaces/openshift/docs/truenas-csi-troubleshooting.md` - Detailed troubleshooting

## Configuration Reference

### Complete Values Structure

```yaml
cluster:
  name: string # Cluster name
  top_level_domain: string # Top-level domain
  storage:
    truenas:
      server:
        host: string # TrueNAS hostname/IP
        port: integer # API port (443 or 80)
        protocol: string # "https" or "http"
        allowInsecure: boolean # Allow self-signed certs
      iscsi:
        targetPortal: string # "host:3260"
        iqnPrefix: string # iSCSI IQN prefix
      zfs:
        datasetParentName: string # ZFS dataset for volumes
        detachedSnapshotsDatasetParentName: string # ZFS dataset for snapshots
        zvolBlocksize: string # Block size (4K, 8K, 16K, etc.)
        zvolCompression: string # Compression (lz4, gzip, etc.)
      secretKeys:
        apiKey: string # Infisical secret key name

democratic-csi:
  # Democratic CSI driver configuration
  # See https://github.com/democratic-csi/charts for full options
```

## Advanced Configuration

### Custom Storage Class Settings

Modify the storage class settings:

```yaml
democratic-csi:
  storageClasses:
    - name: truenas-iscsi-fast
      defaultClass: false
      reclaimPolicy: Retain
      volumeBindingMode: WaitForFirstConsumer
      allowVolumeExpansion: true
      parameters:
        csi.storage.k8s.io/fstype: xfs
```

### Multiple Storage Classes

You can define multiple storage classes for different use cases:

```yaml
democratic-csi:
  storageClasses:
    - name: truenas-iscsi
      defaultClass: true
      reclaimPolicy: Delete
      parameters:
        csi.storage.k8s.io/fstype: ext4

    - name: truenas-iscsi-retain
      defaultClass: false
      reclaimPolicy: Retain
      parameters:
        csi.storage.k8s.io/fstype: ext4
```

## Support

For issues specific to:

- **This chart**: Check the troubleshooting documentation
- **Democratic CSI**: https://github.com/democratic-csi/democratic-csi
- **TrueNAS API**: https://www.truenas.com/docs/api/

## License

This chart is provided as-is without warranty.
