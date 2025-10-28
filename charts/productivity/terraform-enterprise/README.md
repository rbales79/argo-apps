# Terraform Enterprise

This Helm chart deploys HashiCorp Terraform Enterprise on OpenShift/Kubernetes.

## Overview

Terraform Enterprise is HashiCorp's self-hosted distribution of Terraform Cloud. It provides:

- Private Terraform module registry
- Remote state management
- Collaborative runs
- Sentinel policy as code
- VCS integration (GitHub, GitLab, Bitbucket, etc.)
- SSO/SAML integration
- Audit logging
- Cost estimation
- Private agents

## Prerequisites

- OpenShift 4.x or Kubernetes 1.22+
- Helm 3.x
- Valid Terraform Enterprise license
- External Secrets Operator installed and configured
- cert-manager installed (optional, for automatic TLS)
- Storage class for persistent volumes (default: `truenas-iscsi`)

## Architecture

This deployment includes:

1. **Terraform Enterprise application** - Main TFE container
2. **PostgreSQL sidecar** - Internal database (or connect to external)
3. **Persistent storage** - For application data, configuration, and database
4. **TLS certificates** - Via cert-manager or manual
5. **OpenShift Routes** - For application and admin console access
6. **Gatus monitoring** - Health check integration

### Deployment Modes

- **Mounted Disk** (default): Uses local persistent volumes for data storage
- **External Services**: Uses external PostgreSQL and S3-compatible object storage

## Installation

### Step 1: Obtain Terraform Enterprise License

Contact HashiCorp to obtain a Terraform Enterprise license file or license string.

### Step 2: Store Secrets in Infisical

Store the following secrets in your Infisical project:

```bash
# Required secrets
TERRAFORM_ENTERPRISE_LICENSE=<your-license-string>
TERRAFORM_ENTERPRISE_ENCRYPTION_PASSWORD=<strong-random-password>
TERRAFORM_ENTERPRISE_ADMIN_PASSWORD=<admin-user-password>
TERRAFORM_ENTERPRISE_DB_PASSWORD=<database-password>

# Optional: For external object storage (S3)
TERRAFORM_ENTERPRISE_S3_ACCESS_KEY=<s3-access-key>
TERRAFORM_ENTERPRISE_S3_SECRET_KEY=<s3-secret-key>
```

Generate strong passwords:

```bash
# Encryption password (min 32 characters)
openssl rand -base64 32

# Admin password
openssl rand -base64 24

# Database password
openssl rand -base64 24
```

### Step 3: Configure values.yaml

Edit `values.yaml` or override via Argo CD:

```yaml
cluster:
  name: production
  top_level_domain: company.com
  admin_email: admin@company.com

terraformEnterprise:
  # Deployment mode: "mounted-disk" or "external"
  deploymentMode: mounted-disk

  # TLS configuration
  tls:
    enabled: true
    certManager:
      enabled: true
      issuer: letsencrypt-production
      issuerKind: ClusterIssuer

  # Database configuration
  database:
    external: false # Use internal PostgreSQL sidecar
    name: terraform_enterprise
    user: postgres

  # Admin user
  admin:
    username: admin
    email: admin@company.com

# Resource allocation
pods:
  main:
    resources:
      requests:
        cpu: 1000m
        memory: 2Gi
      limits:
        cpu: 4000m
        memory: 8Gi

  postgres:
    resources:
      requests:
        cpu: 250m
        memory: 512Mi
      limits:
        cpu: 1000m
        memory: 2Gi

# Storage
persistence:
  data:
    size: 50Gi
  postgres:
    size: 20Gi
  config:
    size: 1Gi
```

### Step 4: Deploy via Argo CD

The chart will be automatically deployed by Argo CD when added to the productivity ApplicationSet.

Ensure `terraform-enterprise` is listed in your ApplicationSet:

```yaml
# In cluster/templates/productivity.yaml
generators:
  - list:
      elements:
        - name: terraform-enterprise
```

### Step 5: Initial Setup

After deployment, access the admin console to complete setup:

```bash
# Get the console URL
oc get route terraform-enterprise-console -n terraform-enterprise

# Example: https://terraform-enterprise-console.sno.roybales.com
```

1. Access the admin console at the console URL
2. Upload your license file or paste the license string
3. Configure TLS settings
4. Create the initial admin user (credentials from Infisical)
5. Complete the initial setup wizard

### Step 6: Access Terraform Enterprise

```bash
# Get the main application URL
oc get route terraform-enterprise -n terraform-enterprise

# Example: https://terraform.sno.roybales.com
```

## Configuration

### Deployment Modes

#### Mounted Disk (Default)

Uses persistent volumes for all data storage:

```yaml
terraformEnterprise:
  deploymentMode: mounted-disk
  database:
    external: false # Uses PostgreSQL sidecar
```

#### External Services

Uses external PostgreSQL and S3 object storage:

```yaml
terraformEnterprise:
  deploymentMode: external

  database:
    external: true
    host: postgres.company.com
    port: 5432
    name: terraform_enterprise
    user: tfe_user

  objectStorage:
    enabled: true
    type: s3
    s3:
      bucket: terraform-enterprise
      region: us-east-1
      endpoint: s3.amazonaws.com # or MinIO endpoint
```

### TLS Configuration

#### Option 1: cert-manager (Recommended)

```yaml
terraformEnterprise:
  tls:
    enabled: true
    certManager:
      enabled: true
      issuer: letsencrypt-production
      issuerKind: ClusterIssuer
```

#### Option 2: Manual Certificate

1. Create a TLS secret manually:

```bash
oc create secret tls terraform-enterprise-tls \
  --cert=path/to/cert.pem \
  --key=path/to/key.pem \
  -n terraform-enterprise
```

2. Configure:

```yaml
terraformEnterprise:
  tls:
    enabled: true
    certManager:
      enabled: false
```

### Resource Requirements

#### Minimum (Testing)

```yaml
pods:
  main:
    resources:
      requests:
        cpu: 500m
        memory: 1Gi
      limits:
        cpu: 2000m
        memory: 4Gi
```

#### Production (Recommended)

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

### High Availability

For production deployments:

1. Use external PostgreSQL with replication
2. Use external object storage (S3/Azure/GCS)
3. Enable Redis for session management
4. Scale to multiple replicas (requires external services)

```yaml
terraformEnterprise:
  deploymentMode: external
  database:
    external: true
  objectStorage:
    enabled: true
  redis:
    enabled: true

# Enable horizontal scaling
pods:
  main:
    replicas: 3
```

## Usage

### Creating Your First Workspace

1. Log into Terraform Enterprise
2. Create an organization
3. Create a workspace
4. Connect to VCS (GitHub, GitLab, etc.)
5. Configure variables
6. Run terraform plan/apply

### CLI Configuration

Configure the Terraform CLI to use your TFE instance:

```bash
# Add to ~/.terraformrc or terraform.rc
credentials "terraform.sno.roybales.com" {
  token = "your-api-token"
}
```

### API Access

```bash
# Generate an API token in the UI
TFE_TOKEN="your-api-token"
TFE_HOST="terraform.sno.roybales.com"

# Example API call
curl -H "Authorization: Bearer $TFE_TOKEN" \
  https://$TFE_HOST/api/v2/organizations
```

## Monitoring

### Gatus Health Checks

The chart includes Gatus monitoring integration:

```yaml
gatus:
  enabled: true
  interval: 5m
  conditions:
    - "[STATUS] == 200"
    - "[RESPONSE_TIME] < 3000"
```

### Application Metrics

Access metrics via the admin console:

- System health status
- Resource utilization
- Run statistics
- User activity

### Logs

```bash
# View application logs
oc logs -f statefulset/terraform-enterprise -c terraform-enterprise -n terraform-enterprise

# View PostgreSQL logs (if using sidecar)
oc logs -f statefulset/terraform-enterprise -c postgres -n terraform-enterprise

# View recent events
oc get events -n terraform-enterprise --sort-by='.lastTimestamp'
```

## Backup and Recovery

### Backup Strategy

For mounted-disk mode:

1. **Application data**: Backup `/var/lib/terraform-enterprise` PVC
2. **PostgreSQL data**: Backup `/var/lib/postgresql/data` PVC
3. **Configuration**: Backup `/etc/terraform-enterprise` PVC

Using Kasten K10:

```yaml
# The StatefulSet is labeled with kasten/backup: "true"
# Kasten will automatically discover and backup the workload
```

Manual backup:

```bash
# Create PVC snapshots
oc get pvc -n terraform-enterprise
oc create volumesnapshot terraform-enterprise-data-snap \
  --volumesnapshotclass=truenas-iscsi \
  --source=data-terraform-enterprise-0
```

### Disaster Recovery

1. Ensure secrets are backed up in Infisical
2. Restore PVCs from snapshots
3. Redeploy the chart
4. Terraform Enterprise will automatically restore from persisted data

## Troubleshooting

### Application Won't Start

```bash
# Check pod status
oc get pods -n terraform-enterprise

# Check logs
oc logs -f statefulset/terraform-enterprise -n terraform-enterprise

# Check events
oc describe statefulset terraform-enterprise -n terraform-enterprise
```

Common issues:

- **License error**: Verify `TERRAFORM_ENTERPRISE_LICENSE` secret
- **Database connection**: Check PostgreSQL container logs
- **Permission errors**: Check PVC permissions and SecurityContextConstraints

### Database Issues

```bash
# Connect to PostgreSQL
oc exec -it terraform-enterprise-0 -c postgres -n terraform-enterprise -- psql -U postgres -d terraform_enterprise

# Check database status
\l  # List databases
\dt # List tables
\q  # Quit
```

### TLS Certificate Issues

```bash
# Check certificate status
oc get certificate -n terraform-enterprise

# Describe certificate
oc describe certificate terraform-enterprise-tls -n terraform-enterprise

# Check cert-manager logs
oc logs -n cert-manager deployment/cert-manager
```

### Performance Issues

1. Check resource utilization:

```bash
oc top pod -n terraform-enterprise
```

2. Increase resources in values.yaml
3. Consider enabling Redis for caching
4. Move to external database and object storage

### Storage Issues

```bash
# Check PVC status
oc get pvc -n terraform-enterprise

# Check PV status
oc get pv | grep terraform-enterprise

# Check storage usage
oc exec terraform-enterprise-0 -n terraform-enterprise -- df -h
```

## Upgrading

### Upgrade TFE Version

1. Update the image tag in `values.yaml`:

```yaml
pods:
  main:
    image:
      tag: "v202411-1" # New version
```

2. Argo CD will automatically detect and apply the change
3. The StatefulSet will perform a rolling update

### Backup Before Upgrade

Always backup before upgrading:

```bash
# Create VolumeSnapshots of all PVCs
oc get pvc -n terraform-enterprise -o name | xargs -I {} oc create volumesnapshot {}-pre-upgrade --volumesnapshotclass=truenas-iscsi --source={}
```

## Security Considerations

1. **Use strong encryption passwords** (min 32 characters)
2. **Enable TLS** for all traffic
3. **Rotate secrets regularly** via Infisical
4. **Use external database** for production (with encryption at rest)
5. **Enable audit logging** in TFE settings
6. **Configure SSO/SAML** for user authentication
7. **Use Sentinel policies** for infrastructure compliance
8. **Restrict network access** via NetworkPolicies
9. **Regular security updates** - keep TFE version current

## Support

- **Terraform Enterprise Documentation**: https://developer.hashicorp.com/terraform/enterprise
- **HashiCorp Support**: Contact your HashiCorp account team
- **Community**: https://discuss.hashicorp.com/

## License

Requires a valid Terraform Enterprise license from HashiCorp.
