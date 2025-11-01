# OpenShift Cluster Bootstrap Instructions

This document provides step-by-step instructions for bootstrapping an OpenShift cluster with Argo CD using this GitOps repository.

## Prerequisites

- OpenShift cluster (OKD 4.12+ or OpenShift 4.12+)
- `oc` CLI tool configured and authenticated to the cluster
- `kubectl` CLI tool (optional, but recommended)
- Cluster admin privileges

## Bootstrap Process Overview

The bootstrap process involves:

1. Installing the OpenShift GitOps operator (Argo CD) on the cluster
2. Configuring Argo CD with cluster-admin permissions
3. Creating external secrets (if using External Secrets Operator with Infisical)
4. Creating the initial "cluster" Application pointing to `roles/<cluster-name>/`
5. Argo CD automatically deploying ApplicationSets from the role chart
6. ApplicationSets creating individual Applications for each enabled app

## Architecture Overview

This repository uses an **ApplicationSet-based GitOps architecture**:

- **Bootstrap** (manual): Create one Argo CD `Application` named "cluster" pointing to `roles/<cluster-name>/`
- **Roles** (Helm charts): Each cluster role (sno, hub, test, template) is a complete Helm chart that deploys **ApplicationSets**
- **ApplicationSets**: Each functional group (ai, media, security, etc.) is an ApplicationSet that generates child Applications
- **Charts**: Individual application Helm charts in `charts/<domain>/<app>/`

**Available cluster roles:**

- `sno` - Single Node OpenShift configuration
- `hub` - Management cluster configuration
- `test` - Testing cluster configuration
- `template` - Reference template for new clusters

## Step 1: Install Argo CD

Install the Argo CD operator in the `openshift-gitops` namespace:

```bash
# Create the GitOps operator subscription
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-gitops-operator
  namespace: openshift-operators
spec:
  channel: latest
  installPlanApproval: Automatic
  name: openshift-gitops-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

Wait for the operator to be installed and the `openshift-gitops` namespace to be created:

```bash
oc get pods -n openshift-gitops
```

## Step 2: Give Argo CD Cluster Admin Rights

Create a ClusterRoleBinding to grant Argo CD the necessary permissions:

```bash
oc apply -f - <<EOF
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: openshift-gitops-argocd-application-controller-cluster-admin
subjects:
  - kind: ServiceAccount
    name: openshift-gitops-argocd-application-controller
    namespace: openshift-gitops
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
EOF
```

## Step 3: Create External Secrets (Optional)

If using External Secrets Operator with Infisical, create the authentication secret:

```bash
oc apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: infisical-auth-secret
  namespace: openshift-gitops
type: Opaque
stringData:
  clientId: "your-infisical-client-id"
  clientSecret: "your-infisical-client-secret"
EOF
```

> **Note:** Skip this step if you're not using External Secrets Operator or if you're using a different secrets management solution.

## Step 4: Create the Cluster Application

Create the main cluster Application pointing to your chosen role. The `path` should be `roles/<cluster-role>` where cluster-role is one of: `sno`, `hub`, `test`, or `template`.

**Example for Single Node OpenShift (sno):**

```bash
oc apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cluster
  namespace: openshift-gitops
spec:
  destination:
    namespace: openshift-gitops
    server: "https://kubernetes.default.svc"
  project: default
  source:
    helm:
      parameters:
        - name: config.cluster.admin_email
          value: "YOUR_EMAIL@example.com"
        - name: config.cluster.name
          value: "YOUR_CLUSTER_NAME"
        - name: config.cluster.timezone
          value: "America/New_York"
        - name: config.cluster.top_level_domain
          value: "example.local"
        - name: spec.source.repoURL
          value: "https://github.com/YOUR_USERNAME/argo-apps"
        - name: spec.source.targetRevision
          value: "HEAD"
    path: roles/sno
    repoURL: "https://github.com/YOUR_USERNAME/argo-apps"
    targetRevision: HEAD
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
```

> **Important:** Change `path: roles/sno` to match your cluster role (`roles/hub`, `roles/test`, etc.)

## Step 5: Customize Configuration

Replace the following placeholder values in the Application manifest above:

- `YOUR_EMAIL@example.com`: Your admin email address
- `YOUR_CLUSTER_NAME`: A short name for your cluster (e.g., "sno", "hub", "lab01")
- `America/New_York`: Your timezone (see [TZ database names](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones))
- `example.local`: Your cluster's top-level domain (e.g., "roybales.com", "homelab.local")
- `YOUR_USERNAME`: Your GitHub username or organization
- `roles/sno`: Change to match your cluster role (`roles/hub`, `roles/test`, etc.)

**Additional configuration options** (add as Helm parameters if needed):

- `config.cluster.storage.config.storageClassName`: Default storage class (e.g., "truenas-iscsi")
- `config.plex.network.ip`: Static IP for Plex (if using)
- `config.emqx.network.ip`: Static IP for EMQX MQTT broker (if using)
- `config.certificates.letsencrypt.issuer`: Certificate issuer ("production" or "staging")
- `config.externalSecrets.infisical.projectSlug`: Infisical project name (if using ESO)
- `config.externalSecrets.infisical.environmentSlug`: Infisical environment (e.g., "prod", "dev")

## Step 6: Deploy and Verify

After applying the cluster Application, Argo CD will:

1. Deploy the role Helm chart from `roles/<cluster-name>/`
2. Create ApplicationSets for each functional group:
   - **Security** (sync-wave: 0): External Secrets Operator, RBAC resources
   - **Storage** (sync-wave: 50): TrueNAS CSI, Synology CSI
   - **Apps** (sync-wave: 100): AI, Media, Home Automation, Productivity applications
   - **Tweaks** (sync-wave: 200): Interface disablers, snapshot cleanup
3. ApplicationSets automatically generate child Applications for enabled apps
4. Each app deploys to its own namespace with resources defined in `charts/<domain>/<app>/`

### Monitor Deployment Progress

Check the main cluster Application:

```bash
# View the cluster Application status
oc get application cluster -n openshift-gitops

# Check if ApplicationSets were created
oc get applicationsets -n openshift-gitops
```

Expected ApplicationSets (varies by cluster role):

```bash
# Example for 'sno' role
oc get applicationset -n openshift-gitops
# Should see: sno-ai, sno-media, sno-base, sno-home-automation,
#             sno-productivity, etc.
```

Monitor individual Applications:

```bash
# List all Applications created by ApplicationSets
oc get applications -n openshift-gitops

# Watch application sync status in real-time
oc get applications -n openshift-gitops -w

# Check specific application details
oc describe application <app-name> -n openshift-gitops
```

Verify application deployments:

```bash
# List all namespaces (each app gets its own namespace)
oc get namespaces | grep -v "openshift\|kube"

# Check pods in a specific application namespace
oc get pods -n <app-name>

# View application routes
oc get routes -A | grep -v "openshift"
```

## Customizing Your Deployment

### Enabling/Disabling Applications

Applications are controlled via the ApplicationSet templates in `roles/<cluster-name>/templates/`. To enable or disable apps:

1. Edit the appropriate ApplicationSet template (e.g., `roles/sno/templates/ai.yaml`)
2. Add or remove elements from the `generators.list.elements` array:

```yaml
spec:
  generators:
    - list:
        elements:
          - name: litellm # Enabled
            group: ai
            gatus:
              enabled: true
          - name: open-webui # Enabled
            group: ai
          # - name: jupyter-hub  # Disabled (commented out)
          #   group: ai
```

Commit and push changes - Argo CD will sync automatically.

### Modifying Application Configuration

Each application's configuration is managed via Helm values:

1. **Cluster-level config**: Edit `roles/<cluster-name>/values.yaml` for settings shared across apps
2. **App-specific config**: Edit `charts/<domain>/<app>/values.yaml` for app defaults
3. **Per-instance overrides**: ApplicationSets can pass custom values via `helm.valuesObject`

Example cluster-level configuration (`roles/sno/values.yaml`):

```yaml
config:
  cluster:
    top_level_domain: roybales.com
    name: sno
    admin_email: admin@example.com
    timezone: America/New_York

  certificates:
    letsencrypt:
      issuer: production

  network:
    pod_network: 10.128.0.0/14
    service_network: 172.30.0.0/16
```

## Resource Configuration

### Argo CD Performance Tuning

This repository automatically configures Argo CD resource limits to handle large-scale deployments without crashes. The configuration is deployed as part of the bootstrap process (sync-wave: -1) and includes optimized settings for:

- **Application Controller**: 8Gi memory limit (prevents OOM when managing 25+ applications)
- **ApplicationSet Controller**: 1Gi memory limit
- **Repo Server**: 1Gi memory limit
- **Server, Redis, Dex**: Standard limits for typical workloads

These settings are defined in each role's `values.yaml` under `config.argocd` and can be adjusted based on your cluster's capacity and the number of applications being managed.

**To disable auto-configuration** (e.g., if using custom ArgoCD instance):

```yaml
# In roles/<cluster>/values.yaml
config:
  argocd:
    enabled: false # Disables automatic resource configuration
```

**To customize resource limits** for your specific needs:

```yaml
# In roles/<cluster>/values.yaml
config:
  argocd:
    enabled: true
    controller:
      resources:
        limits:
          cpu: "8" # Increase for very large clusters
          memory: 16Gi # Increase if managing 50+ applications
```

The template file `roles/<cluster>/templates/argocd-resource-config.yaml` applies these settings automatically during bootstrap.

## Troubleshooting

### Argo CD Application Controller Crashing (OOMKilled)

**Symptom:** `openshift-gitops-application-controller-0` pod in CrashLoopBackOff, logs show OOMKilled (exit code 137)

**Cause:** Insufficient memory when managing many applications simultaneously (typically 25+ applications)

**Solution:** This is automatically configured in this repository. If using a custom setup, increase resources:

```bash
oc patch argocd openshift-gitops -n openshift-gitops --type=merge -p '{
  "spec": {
    "controller": {
      "resources": {
        "requests": { "cpu": "500m", "memory": "2Gi" },
        "limits": { "cpu": "4", "memory": "8Gi" }
      }
    }
  }
}'
```

Delete the pod to force recreation: `oc delete pod openshift-gitops-application-controller-0 -n openshift-gitops`

### ApplicationSet Not Creating Applications

**Symptom:** ApplicationSet exists but no child Applications are created

**Solution:**

```bash
# Check ApplicationSet status
oc describe applicationset <name> -n openshift-gitops

# Check for generator errors
oc get applicationset <name> -n openshift-gitops -o yaml

# Delete and let Argo CD recreate it
oc delete applicationset <name> -n openshift-gitops
```

### ResourceVersion Conflicts

**Symptom:** `metadata.resourceVersion: Invalid value: 0x0: must be specified for an update`

**Solution:** Delete the ApplicationSet and let Argo CD recreate it:

```bash
oc delete applicationset <name> -n openshift-gitops
# Wait a few seconds for the cluster Application to recreate it
oc get applicationset -n openshift-gitops -w
```

### Application Stuck in Sync

**Symptom:** Application shows "Syncing" but never completes

**Solution:**

```bash
# Check application status and health
oc describe application <app-name> -n openshift-gitops

# Check pod logs in the app namespace
oc get pods -n <app-name>
oc logs -n <app-name> <pod-name>

# Force a hard refresh
oc patch application <app-name> -n openshift-gitops --type merge \
  -p '{"operation":{"sync":{"syncStrategy":{"hook":{"force":true}}}}}'
```

### Sync Waves Not Working

**Symptom:** Applications deploy in wrong order or fail due to missing dependencies

**Solution:** Verify sync-wave annotations in ApplicationSet templates:

- Wave 0: Security, External Secrets Operator
- Wave 50: Storage providers
- Wave 100: Applications
- Wave 200: Tweaks and optimizations

```bash
# Check sync-wave for ApplicationSets
oc get applicationset -n openshift-gitops -o json | \
  jq -r '.items[] | "\(.metadata.name): \(.metadata.annotations["argocd.argoproj.io/sync-wave"] // "none")"'
```

## Advanced Configuration

### Using Values Files Instead of Parameters

For complex configurations, you can reference a values file instead of inline parameters:

```yaml
spec:
  source:
    helm:
      valueFiles:
        - values.yaml
    path: roles/sno
    repoURL: "https://github.com/YOUR_USERNAME/argo-apps"
```

Then customize `roles/sno/values.yaml` in your fork.

### Multiple Clusters

To manage multiple clusters, create separate cluster Applications pointing to different roles:

```bash
# Cluster 1: Single Node OpenShift
oc apply -f cluster-sno-application.yaml

# Cluster 2: Hub Cluster
oc apply -f cluster-hub-application.yaml
```

Each role can have different apps enabled based on the cluster's purpose.

## Next Steps

1. **Review deployed applications**: Access apps via their Routes (`<app>.apps.<cluster>.<domain>`)
2. **Configure monitoring**: Check Gatus dashboard for application health
3. **Review resource usage**: Use Goldilocks/VPA recommendations for resource tuning
4. **Add custom applications**: Follow the guide in `.github/instructions/adding-a-role.instructions.md`
5. **Set up secrets**: Configure External Secrets Operator for sensitive data management

## Additional Resources

- **Architecture Documentation**: `.github/copilot-instructions.md`
- **Adding Applications**: `.github/instructions/adding-a-role.instructions.md`
- **AI Stack Recommendations**: `docs/ai-stack/recommended-tools.md`
- **TrueNAS CSI Troubleshooting**: `docs/truenas-csi-troubleshooting.md`
- **Argo CD Documentation**: <https://argo-cd.readthedocs.io/>
