# TrueNAS CSI Chart - Configuration Summary

## What Was Created

### 1. Chart Structure

```
charts/storage/truenas/
├── Chart.yaml                      # Chart metadata
├── values.yaml                     # Configuration values (NEW)
├── templates/
│   └── externalsecret.yaml        # ExternalSecret template (NEW)
└── README.md                       # Documentation (NEW)
```

### 2. Values File (`values.yaml`)

**New structure** that matches your working configuration with templateable values:

#### Cluster Configuration

```yaml
cluster:
  name: cluster
  top_level_domain: roybales.com
```

#### TrueNAS Server Settings

```yaml
cluster:
  storage:
    truenas:
      server:
        host: truenas.roybales.com # ← Customize this
        port: 443
        protocol: https
        allowInsecure: true
```

#### iSCSI Configuration

```yaml
iscsi:
  targetPortal: "truenas.roybales.com:3260" # ← Customize this
  iqnPrefix: "iqn.2005-10.org.freenas.ctl"
```

#### ZFS Paths

```yaml
zfs:
  datasetParentName: "volume1/iscsi/test/vols" # ← Customize this
  detachedSnapshotsDatasetParentName: "volume1/iscsi/test/snaps" # ← Customize this
  zvolBlocksize: "16K"
  zvolCompression: "lz4"
```

#### Secret Configuration

```yaml
secretKeys:
  apiKey: TRUENAS_API_KEY # ← Name of secret in Infisical
```

### 3. ExternalSecret Template

The ExternalSecret now:

- ✅ Uses clean value paths (`.Values.cluster.storage.truenas.*`)
- ✅ Properly templates the API key from Infisical
- ✅ Sets `apiVersion: 2` for TrueNAS SCALE/modern API
- ✅ Includes all working iSCSI settings from your config

### 4. Democratic CSI Configuration

Includes your working settings:

- ✅ Controller and node OpenShift RBAC
- ✅ Proper image settings (`democraticcsi/democratic-csi:next`)
- ✅ iSCSI host path configuration
- ✅ `nsenter` strategy for iSCSI commands
- ✅ Storage class with Kasten snapshot annotations
- ✅ References `existingConfigSecret`

## How to Use

### Customization Points

You can now easily customize through values:

1. **For different clusters:**

   ```yaml
   cluster:
     name: production-cluster
     top_level_domain: mycompany.com
   ```

2. **For different TrueNAS servers:**

   ```yaml
   cluster:
     storage:
       truenas:
         server:
           host: truenas-backup.mycompany.com
           port: 8443
   ```

3. **For different storage paths:**

   ```yaml
   cluster:
     storage:
       truenas:
         zfs:
           datasetParentName: "pool2/kubernetes/volumes"
           detachedSnapshotsDatasetParentName: "pool2/kubernetes/snapshots"
   ```

4. **For different secret names:**
   ```yaml
   cluster:
     storage:
       truenas:
         secretKeys:
           apiKey: TRUENAS_PROD_API_KEY
   ```

### Value Inheritance

The chart follows the repository pattern where cluster-wide config can be passed through ApplicationSet:

```yaml
# In ApplicationSet template
helm:
  valuesObject:
    cluster:
{{ .Values.cluster | toYaml | nindent 6 }}
```

This means your cluster values from `cluster/values.yaml` automatically flow down.

## Key Improvements

### From Your Working Config

✅ **API Key Format**: Uses proper template syntax for Infisical integration

```yaml
apiKey: "{{ .TRUENAS_API_KEY }}"
```

✅ **All Working Settings**: Includes everything from your working YAML:

- iSCSI extent settings
- Target group configuration
- CHAP disabled
- Thin provisioning enabled
- SSD extent RPM
- Proper blocksize (4096)

### Additional Features

✅ **API Version 2**: Explicitly sets `apiVersion: 2` for modern TrueNAS
✅ **Clean Structure**: Organized configuration hierarchy
✅ **Documentation**: Comprehensive README with examples
✅ **Troubleshooting**: Diagnostic scripts and guides

## Next Steps

1. **Review `values.yaml`** - Customize for your environment
2. **Verify API Key** in Infisical - Ensure `TRUENAS_API_KEY` exists and is correct
3. **Deploy** via Argo CD - Let the ApplicationSet sync it
4. **Test Connection** using diagnostic script:
   ```bash
   /workspaces/openshift/scripts/diagnose-truenas-csi.sh
   ```

## Migration from Old Config

If you had an old configuration, the new structure is cleaner:

**Old:**

```yaml
cluster:
  storage:
    democratic-csi:
      httpConnection:
        host: ...
```

**New:**

```yaml
cluster:
  storage:
    truenas:
      server:
        host: ...
```

The values are more logically organized and easier to understand.

## Files Updated

- ✅ `charts/storage/truenas/values.yaml` - Created with full configuration
- ✅ `charts/storage/truenas/templates/externalsecret.yaml` - Created with proper templating
- ✅ `charts/storage/truenas/README.md` - Created with documentation
- ✅ `scripts/diagnose-truenas-csi.sh` - Updated for troubleshooting
- ✅ `docs/truenas-csi-quick-fix.md` - Updated with common fixes
- ✅ `docs/truenas-csi-troubleshooting.md` - Updated with detailed troubleshooting

All files are ready for use!
