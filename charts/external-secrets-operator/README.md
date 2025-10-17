# External Secrets Operator with Infisical

This chart deploys and configures the External Secrets Operator (ESO) to work with Infisical as a secret backend for your OpenShift cluster.

## Overview

External Secrets Operator synchronizes secrets from external secret management systems (like Infisical) into Kubernetes secrets. This integration allows you to:

- Centrally manage secrets in Infisical
- Automatically sync secrets to Kubernetes
- Rotate secrets without manual intervention
- Maintain audit logs of secret access
- Separate secret management from cluster operations

## Prerequisites

1. **Infisical Account**
   - Sign up at [Infisical Cloud](https://app.infisical.com) or deploy a self-hosted instance
   - Create a project for your cluster secrets

2. **External Secrets Operator**
   - The operator will be installed automatically via the `OperatorConfig` in this chart
   - OpenShift cluster with cluster-admin permissions

3. **Universal Auth Credentials**
   - Create a Machine Identity in Infisical with Universal Auth enabled
   - Note the Client ID and Client Secret

## Setup Instructions

### Step 1: Create Infisical Project and Machine Identity

1. **Create a Project in Infisical:**
   ```
   - Log into Infisical (https://app.infisical.com)
   - Create a new project (e.g., "openshift" or your cluster name)
   - Note the project slug (visible in the URL or project settings)
   ```

2. **Create a Machine Identity:**
   ```
   - Navigate to Project Settings → Machine Identities(validate org settings-> access control - machine identities)
   - Click "Create Machine Identity"
   - Name it (e.g., "external-secrets-operator")
   - Enable "Universal Auth"
   - Note the Client ID and Client Secret (save these securely!)
   - Grant appropriate permissions (read access to secrets)
   ```

3. **Configure Environment:**
   ```
   - Create an environment in your project (e.g., "prod", "dev", "staging")
   - Note the environment slug
   - Add your secrets to this environment
   ```

### Step 2: Create the Authentication Secret in OpenShift

The External Secrets Operator needs credentials to authenticate with Infisical. Create a secret in the `openshift-gitops` namespace:

```bash
oc create secret generic infisical-auth-secret \
  --from-literal=clientId='YOUR_CLIENT_ID' \
  --from-literal=clientSecret='YOUR_CLIENT_SECRET' \
  -n openshift-gitops
```

**Important:** This secret must exist before deploying this chart, as it's referenced by the ClusterSecretStore.

### Step 3: Configure Chart Values

Update the `values.yaml` file with your Infisical configuration:

```yaml
externalSecrets:
  secret: infisical-auth-secret  # Name of the secret created in Step 2
  infisical:
    projectSlug: openshift         # Your Infisical project slug
    environmentSlug: prod          # Your Infisical environment slug
    auth:
      clientId: infisical-auth-secret  # Secret name containing credentials
```

### Step 4: Deploy the Chart

The chart will be automatically deployed by Argo CD when you add it to the security ApplicationSet template.

The deployment creates:
1. **OperatorConfig** (sync-wave: 1) - Installs the External Secrets Operator
2. **ClusterSecretStore** (sync-wave: 2) - Configures Infisical as the secret backend

### Step 5: Verify the Installation

1. **Check Operator Pods:**
   ```bash
   oc get pods -n external-secrets
   ```

   You should see pods running for:
   - external-secrets-controller
   - external-secrets-webhook
   - external-secrets-cert-controller

2. **Verify ClusterSecretStore:**
   ```bash
   oc get clustersecretstore
   ```

   Output should show:
   ```
   NAME               AGE   STATUS   CAPABILITIES   READY
   external-secrets   1m    Valid    ReadWrite      True
   ```

3. **Check for Errors:**
   ```bash
   oc get clustersecretstore external-secrets -o yaml
   ```

   Look for the `status` section - it should show `Ready: true`

## Using External Secrets

Once configured, you can create `ExternalSecret` resources to sync secrets from Infisical.

### Example 1: Sync a Single Secret

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: radarr-secret
  namespace: my-app
spec:
  refreshInterval: 5m
  secretStoreRef:
    kind: ClusterSecretStore
    name: external-secrets # References the ClusterSecretStore created by this chart
  target:
    name: radarr-secret
    creationPolicy: Owner
  data:
    - secretKey: database-password
      remoteRef:
        key: DATABASE_PASSWORD # Key in Infisical
```

### Example 2: Sync All Secrets from a Path

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-app-secrets
  namespace: my-app
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: external-secrets
    kind: ClusterSecretStore
  target:
    name: my-app-secrets
    creationPolicy: Owner
  dataFrom:
    - find:
        path: /              # Sync all secrets from root path
        name:
          regexp: "^MY_APP_.*"  # Optional: filter by regex
```

### Example 3: Use Template for Environment Variables

```yaml
---
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/external-secrets.io/externalsecret_v1beta1.json
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: radarr
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: external-secrets
  target:
    name: radarr-secret
    template:
      engineVersion: v2
      mergePolicy: Replace
      data:
        RADARR__AUTH__APIKEY: "{{ .RADARR_API_KEY }}"
  dataFrom:
    - find:
        path: RADARR_API_KEY
```

## Secret Organization in Infisical

Best practices for organizing secrets:

### Option 1: Use Secret Paths (Folders)

```text
Project: openshift
Environment: prod
├── /database
│   ├── DB_HOST
│   ├── DB_USER
│   └── DB_PASSWORD
├── /api
│   ├── API_KEY
│   └── API_SECRET
└── /shared
    └── TLS_CERT
```

### Option 2: Use Naming Conventions

```text
Project: openshift
Environment: prod
├── POSTGRES_HOST
├── POSTGRES_USER
├── POSTGRES_PASSWORD
├── REDIS_HOST
├── REDIS_PASSWORD
└── APP_SECRET_KEY
```

## Troubleshooting

### ClusterSecretStore Not Ready

**Problem:** `oc get clustersecretstore` shows status as `Invalid` or `Not Ready`

**Solutions:**

1. Check the authentication secret exists:

   ```bash
   oc get secret infisical-auth-secret -n openshift-gitops
   ```

2. Verify credentials are correct:

   ```bash
   oc get secret infisical-auth-secret -n openshift-gitops -o yaml
   ```

   Decode the clientId and clientSecret to verify they match your Infisical settings

3. Check operator logs:

   ```bash
   oc logs -n external-secrets -l app.kubernetes.io/name=external-secrets
   ```

### ExternalSecret Not Syncing

**Problem:** ExternalSecret resource exists but Kubernetes secret is not created

**Solutions:**

1. Check ExternalSecret status:

   ```bash
   oc describe externalsecret my-app-secret -n my-app
   ```

2. Verify the secret exists in Infisical at the specified path

3. Check operator logs for authentication or permission errors

4. Ensure the ClusterSecretStore is Ready (see above)

### Operator Pods Not Starting

**Problem:** External Secrets Operator pods are in CrashLoopBackOff

**Solutions:**

1. Check pod events:

   ```bash
   oc describe pod -n external-secrets -l app.kubernetes.io/name=external-secrets
   ```

2. Check pod logs:

   ```bash
   oc logs -n external-secrets -l app.kubernetes.io/name=external-secrets --all-containers
   ```

3. Verify OperatorConfig was applied:

   ```bash
   oc get operatorconfig external-secrets -n openshift-gitops -o yaml
   ```

### CRD Not Found Errors

**Problem:** Argo CD shows errors about missing CRDs

**Solutions:**

1. This is normal during initial deployment. The sync waves ensure proper ordering:
   - Wave 1: OperatorConfig (installs operator and CRDs)
   - Wave 2: ClusterSecretStore (uses CRDs)

2. Wait for Argo CD retry (configured with exponential backoff up to 16 minutes)

3. Manually trigger a sync if needed:

   ```bash
   argocd app sync external-secrets-operator
   ```

## Security Considerations

1. **Credential Protection:**
   - The `infisical-auth-secret` contains sensitive credentials
   - Never commit these credentials to Git
   - Use OpenShift RBAC to restrict access to this secret
   - Consider using SealedSecrets or SOPS for GitOps workflow

2. **Least Privilege:**
   - Grant Machine Identity only the minimum required permissions in Infisical
   - Use separate Machine Identities for different environments
   - Regularly rotate the Client ID and Client Secret

3. **Audit Logging:**
   - Enable audit logging in Infisical to track secret access
   - Monitor ExternalSecret sync failures
   - Set up alerts for authentication failures

4. **Network Security:**
   - Ensure network connectivity between OpenShift and Infisical API (https://app.infisical.com/api)
   - For self-hosted Infisical, configure appropriate firewall rules
   - Consider using private endpoints if available

## Advanced Configuration

### Custom Infisical Instance

To use a self-hosted Infisical instance, update the ClusterSecretStore:

```yaml
# In templates/clustersecretstore.yaml
spec:
  provider:
    infisical:
      hostAPI: https://infisical.your-domain.com/api  # Your instance URL
```

### Multiple Secret Stores

You can create multiple ClusterSecretStores for different Infisical projects:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: infisical-staging
spec:
  provider:
    infisical:
      auth:
        universalAuthCredentials:
          clientId:
            key: clientId
            namespace: openshift-gitops
            name: infisical-staging-auth
          clientSecret:
            key: clientSecret
            namespace: openshift-gitops
            name: infisical-staging-auth
      secretsScope:
        projectSlug: openshift
        environmentSlug: staging  # Different environment
        secretsPath: /
        recursive: true
      hostAPI: https://app.infisical.com/api
```

### Refresh Intervals

Control how often secrets are synced:

```yaml
spec:
  refreshInterval: 5m  # Options: 1m, 5m, 1h, 24h, etc.
```

- Shorter intervals: More current secrets, higher API usage
- Longer intervals: Lower API usage, potentially stale secrets
- Recommended: 1h for most use cases

## Configuration

### Values

| Parameter                                   | Description                                                         | Default                |
| ------------------------------------------- | ------------------------------------------------------------------- | ---------------------- |
| `externalSecrets.secret`                    | Name of the Kubernetes secret containing Infisical auth credentials | `infisical-auth-secret` |
| `externalSecrets.infisical.projectSlug`     | Infisical project slug                                              | `openshift`            |
| `externalSecrets.infisical.environmentSlug` | Infisical environment slug                                          | `prod`                 |

### Infisical Configuration

The ClusterSecretStore is configured to:

- Pull secrets from the root path (`/`) recursively
- Use the Infisical cloud instance (`https://app.infisical.com`)
- Authenticate using Universal Auth credentials stored in Kubernetes secrets

## References

- [External Secrets Operator Documentation](https://external-secrets.io/)
- [Infisical Documentation](https://infisical.com/docs)
- [Infisical Universal Auth](https://infisical.com/docs/documentation/platform/identities/universal-auth)
- [ExternalSecret API Reference](https://external-secrets.io/latest/api/externalsecret/)
- [ClusterSecretStore API Reference](https://external-secrets.io/latest/api/clustersecretstore/)

## Support

For issues specific to:

- **External Secrets Operator:** [GitHub Issues](https://github.com/external-secrets/external-secrets/issues)
- **Infisical:** [GitHub Issues](https://github.com/Infisical/infisical/issues)
- **This Chart:** Open an issue in this repository
