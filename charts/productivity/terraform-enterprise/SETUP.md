# Terraform Enterprise Deployment - Quick Setup Guide

## Overview

This guide provides step-by-step instructions to deploy Terraform Enterprise to your OpenShift cluster.

## What Was Created

### Chart Structure

```
charts/productivity/terraform-enterprise/
├── Chart.yaml                       # Helm chart metadata
├── values.yaml                      # Configuration values
├── README.md                        # Comprehensive documentation
└── templates/
    ├── namespace.yaml               # Namespace creation
    ├── serviceaccount.yaml          # Service account
    ├── securitycontextconstraints.yaml  # OpenShift SCC
    ├── statefulset.yaml             # Main deployment (TFE + PostgreSQL)
    ├── service.yaml                 # Kubernetes service
    ├── route.yaml                   # OpenShift routes (app + console)
    ├── certificate.yaml             # TLS certificate (cert-manager)
    ├── externalsecret.yaml          # External secrets (license, passwords)
    ├── links.yaml                   # OpenShift console links
    └── gatus-config.yaml            # Health monitoring
```

### Features Included

✅ **Terraform Enterprise application container**
✅ **PostgreSQL sidecar database** (or external database support)
✅ **Persistent storage** for application data, config, and database
✅ **TLS certificates** via cert-manager (Let's Encrypt)
✅ **External Secrets Operator** integration for secure credential management
✅ **OpenShift Routes** for external access
✅ **OpenShift Console Links** for easy navigation
✅ **Gatus monitoring** integration
✅ **Security Context Constraints** for OpenShift security
✅ **Kasten K10** backup labels
✅ **Resource limits and requests**
✅ **Health checks** (liveness/readiness probes)
✅ **Init container** for permission fixing

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    StatefulSet Pod                      │
│                                                         │
│  ┌──────────────────────┐  ┌─────────────────────────┐ │
│  │  TFE Container       │  │  PostgreSQL Container   │ │
│  │  - Port 8080 (HTTP)  │  │  - Port 5432           │ │
│  │  - Port 8443 (HTTPS) │  │  - Internal database   │ │
│  │  - Port 8800 (Admin) │  │                         │ │
│  └──────────────────────┘  └─────────────────────────┘ │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │              Persistent Volumes                   │  │
│  │  - data: 50Gi (TFE application data)            │  │
│  │  - config: 1Gi (TFE configuration)              │  │
│  │  - postgres-data: 20Gi (database)               │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
          ┌───────────────────────────────┐
          │      Kubernetes Service       │
          │   - ClusterIP                 │
          └───────────────────────────────┘
                          │
          ┌───────────────┴──────────────────┐
          │                                  │
          ▼                                  ▼
┌──────────────────────┐        ┌──────────────────────┐
│   OpenShift Route    │        │   OpenShift Route    │
│   (Main App)         │        │   (Admin Console)    │
│   terraform.sno...   │        │   tfe-console.sno... │
└──────────────────────┘        └──────────────────────┘
          │                                  │
          ▼                                  ▼
    [Users/Terraform CLI]           [Initial Setup/Admin]
```

## Prerequisites

Before deploying, ensure you have:

1. ✅ **Valid Terraform Enterprise license** from HashiCorp
2. ✅ **External Secrets Operator** installed and configured
3. ✅ **cert-manager** installed with ClusterIssuer configured
4. ✅ **Storage class** available (truenas-iscsi or similar)
5. ✅ **Infisical** or compatible secrets backend configured

## Step-by-Step Deployment

### Step 1: Obtain Terraform Enterprise License

Contact HashiCorp or your account team to obtain:

- License file (.rli file)
- Or license string

### Step 2: Store Secrets in Infisical

You need to create the following secrets in your Infisical project:

```bash
# Required Secrets
TERRAFORM_ENTERPRISE_LICENSE="<your-license-string-or-file-contents>"
TERRAFORM_ENTERPRISE_ENCRYPTION_PASSWORD="<strong-random-32-char-password>"
TERRAFORM_ENTERPRISE_ADMIN_PASSWORD="<admin-password>"
TERRAFORM_ENTERPRISE_DB_PASSWORD="<database-password>"
```

Generate strong passwords:

```bash
# Encryption password (REQUIRED - minimum 32 characters)
openssl rand -base64 32

# Admin password
openssl rand -base64 24

# Database password
openssl rand -base64 24
```

In Infisical:

1. Navigate to your project (e.g., `hub` project)
2. Select environment (e.g., `prod`)
3. Add each secret with the exact key names above
4. Save

### Step 3: Update Role Configuration

The chart has already been added to the productivity ApplicationSet in:
`/workspaces/argo-apps/roles/sno/templates/productivity.yaml`

### Step 4: Configure Chart Values (Optional)

The default `values.yaml` is configured for:

- **Deployment mode**: mounted-disk (local storage)
- **Database**: PostgreSQL sidecar
- **TLS**: Enabled via cert-manager
- **Hostname**: `terraform.sno.roybales.com`
- **Storage**: 50Gi data + 20Gi database + 1Gi config

To customize, you can override values in the role template or create a values overlay.

### Step 5: Deploy via Argo CD

The chart will be automatically deployed by Argo CD. To trigger deployment:

```bash
# Commit and push your changes
git add .
git commit -m "Add Terraform Enterprise chart"
git push

# Argo CD will automatically detect and deploy
```

Or manually trigger sync:

```bash
# If you have argocd CLI
argocd app sync terraform-enterprise --grpc-web

# Or via kubectl
kubectl patch application terraform-enterprise -n openshift-gitops --type merge -p '{"operation": {"initiatedBy": {"username": "admin"}}}'
```

### Step 6: Monitor Deployment

```bash
# Watch the pod creation
oc get pods -n terraform-enterprise -w

# Check events
oc get events -n terraform-enterprise --sort-by='.lastTimestamp'

# Check Argo CD application status
oc get application terraform-enterprise -n openshift-gitops

# View logs
oc logs -f statefulset/terraform-enterprise -c terraform-enterprise -n terraform-enterprise
```

### Step 7: Initial Setup

Once the pod is running, access the admin console:

```bash
# Get the console route URL
oc get route terraform-enterprise-console -n terraform-enterprise -o jsonpath='{.spec.host}'
```

Example: `https://terraform-enterprise-console.sno.roybales.com`

1. **Access the admin console** in your browser
2. **Upload license**: Use the license file or paste the license string
3. **Configure TLS**: Should auto-detect from cert-manager certificate
4. **Create admin user**:
   - Username: `admin`
   - Email: `rbales79@gmail.com` (from values)
   - Password: Use the password from `TERRAFORM_ENTERPRISE_ADMIN_PASSWORD`
5. **Complete setup wizard**
6. **Wait for services to initialize** (may take 5-10 minutes)

### Step 8: Access Terraform Enterprise

```bash
# Get the main application route URL
oc get route terraform-enterprise -n terraform-enterprise -o jsonpath='{.spec.host}'
```

Example: `https://terraform.sno.roybales.com`

Access in browser and log in with admin credentials.

## Post-Deployment Configuration

### Configure Terraform CLI

Add to `~/.terraformrc`:

```hcl
credentials "terraform.sno.roybales.com" {
  token = "YOUR_API_TOKEN"
}
```

Generate API token in TFE UI: **User Settings** → **Tokens** → **Create an API token**

### Create First Organization

1. Click **Create Organization**
2. Enter organization name
3. Enter email

### Create First Workspace

1. In your organization, click **New Workspace**
2. Choose VCS connection or CLI-driven
3. Configure workspace settings
4. Add variables (if needed)

### Connect to VCS (Optional)

1. Go to **Settings** → **VCS Providers**
2. Add GitHub, GitLab, Bitbucket, etc.
3. Configure OAuth connection
4. Link workspaces to repositories

## Verification Checklist

- [ ] Pod is running: `oc get pods -n terraform-enterprise`
- [ ] All containers healthy: `oc describe pod terraform-enterprise-0 -n terraform-enterprise`
- [ ] Routes are accessible: `oc get routes -n terraform-enterprise`
- [ ] Certificates are valid: `oc get certificate -n terraform-enterprise`
- [ ] External secrets synced: `oc get externalsecret -n terraform-enterprise`
- [ ] Can access admin console URL
- [ ] Can access main application URL
- [ ] Can log in with admin credentials
- [ ] Gatus monitoring shows healthy: Check Gatus dashboard

## Troubleshooting

### Pod Won't Start

```bash
# Check pod status
oc describe pod terraform-enterprise-0 -n terraform-enterprise

# Check logs
oc logs terraform-enterprise-0 -c terraform-enterprise -n terraform-enterprise
oc logs terraform-enterprise-0 -c postgres -n terraform-enterprise

# Check init container logs
oc logs terraform-enterprise-0 -c init-permissions -n terraform-enterprise
```

### License Error

```bash
# Verify license secret exists and is populated
oc get secret terraform-enterprise-license -n terraform-enterprise -o yaml

# Check if secret data is base64 encoded properly
oc get secret terraform-enterprise-license -n terraform-enterprise -o jsonpath='{.data.license}' | base64 -d | head -c 100
```

### Database Connection Issues

```bash
# Check if PostgreSQL is running
oc logs terraform-enterprise-0 -c postgres -n terraform-enterprise

# Connect to database
oc exec -it terraform-enterprise-0 -c postgres -n terraform-enterprise -- psql -U postgres -d terraform_enterprise

# Inside psql
\l  # List databases
\dt # List tables
\q  # Exit
```

### TLS Certificate Issues

```bash
# Check certificate status
oc get certificate -n terraform-enterprise
oc describe certificate terraform-enterprise-tls -n terraform-enterprise

# Check cert-manager logs
oc logs -n cert-manager deployment/cert-manager

# Manually trigger certificate renewal
oc delete certificate terraform-enterprise-tls -n terraform-enterprise
# Let Argo CD recreate it
```

### Storage Issues

```bash
# Check PVCs
oc get pvc -n terraform-enterprise

# Check if volumes are bound
oc describe pvc data-terraform-enterprise-0 -n terraform-enterprise

# Check storage class
oc get storageclass truenas-iscsi
```

### Permission Denied Errors

```bash
# Check if SCC is applied
oc get scc terraform-enterprise-scc

# Check pod security context
oc get pod terraform-enterprise-0 -n terraform-enterprise -o yaml | grep -A 20 securityContext

# Re-run init container to fix permissions
oc delete pod terraform-enterprise-0 -n terraform-enterprise
```

## Configuration Options

### Use External PostgreSQL

Edit `values.yaml`:

```yaml
terraformEnterprise:
  database:
    external: true
    host: postgres.example.com
    port: 5432
    name: terraform_enterprise
    user: tfe_user

pods:
  postgres:
    enabled: false # Disable sidecar
```

### Use External Object Storage (S3)

```yaml
terraformEnterprise:
  deploymentMode: external

  objectStorage:
    enabled: true
    type: s3
    s3:
      bucket: terraform-enterprise
      region: us-east-1
      endpoint: s3.amazonaws.com
```

Add secrets to Infisical:

```bash
TERRAFORM_ENTERPRISE_S3_ACCESS_KEY="<access-key>"
TERRAFORM_ENTERPRISE_S3_SECRET_KEY="<secret-key>"
```

### Increase Resources for Production

```yaml
pods:
  main:
    resources:
      requests:
        cpu: 2000m
        memory: 4Gi
      limits:
        cpu: 8000m
        memory: 16Gi
```

### Disable TLS (Not Recommended)

```yaml
terraformEnterprise:
  tls:
    enabled: false

route:
  tls:
    enabled: false
```

## Backup and Disaster Recovery

### Automated Backups (Kasten K10)

The StatefulSet is labeled with `kasten/backup: "true"`, so Kasten K10 will automatically:

- Discover the workload
- Create scheduled backups
- Include all PVCs (data, config, postgres-data)

### Manual Backup

```bash
# Create VolumeSnapshots
oc create volumesnapshot terraform-enterprise-data-$(date +%Y%m%d) \
  --volumesnapshotclass=truenas-iscsi \
  --source=data-terraform-enterprise-0 \
  -n terraform-enterprise

oc create volumesnapshot terraform-enterprise-postgres-$(date +%Y%m%d) \
  --volumesnapshotclass=truenas-iscsi \
  --source=postgres-data-terraform-enterprise-0 \
  -n terraform-enterprise
```

### Restore from Backup

1. Delete the StatefulSet (keep PVCs)
2. Restore PVCs from snapshots
3. Recreate StatefulSet (Argo CD will do this automatically)

## Next Steps

1. **Configure SSO/SAML** for enterprise authentication
2. **Set up VCS integration** (GitHub, GitLab, etc.)
3. **Create teams and organizations**
4. **Configure Sentinel policies** for compliance
5. **Set up cost estimation** (if licensed)
6. **Enable audit logging**
7. **Configure notifications** (Slack, webhooks, etc.)
8. **Set up private module registry**

## Resources

- **Terraform Enterprise Docs**: https://developer.hashicorp.com/terraform/enterprise
- **Chart README**: `/workspaces/argo-apps/charts/productivity/terraform-enterprise/README.md`
- **Terraform CLI Docs**: https://developer.hashicorp.com/terraform/cli
- **HashiCorp Support**: Contact your account team

## Summary

You now have a complete Terraform Enterprise deployment with:

- ✅ Secure credential management via External Secrets
- ✅ TLS certificates via cert-manager
- ✅ Persistent storage for data and database
- ✅ Health monitoring via Gatus
- ✅ OpenShift console integration
- ✅ Automatic backups via Kasten K10
- ✅ Production-ready security constraints

Access your instance at: `https://terraform.sno.roybales.com`
