# Repository Structure

This repository uses a GitOps approach with Argo CD to manage OpenShift cluster configurations.

## Architecture

The repository is organized into three main layers:

### 1. Cluster Bootstrap (`cluster/`)

Entry point for cluster deployment. Defines which cluster type to deploy (hub, sno, or test).

### 2. Cluster Types (`roles/`)

Cluster-specific configurations that deploy ApplicationSets for the cluster:

- **`hub/`** - Full-featured hub cluster with all components enabled
- **`sno/`** - Single Node OpenShift with resource-optimized settings
- **`test/`** - Minimal test cluster for development
- **`template/`** - Template for creating new cluster types

Each cluster type contains ApplicationSet templates for:

- Base infrastructure (base-apps.yaml, base-security.yaml, base-storage.yaml, base-tweaks.yaml)
- Functional applications (ai.yaml, media.yaml, home-automation.yaml, productivity.yaml)

### 3. Functional Application Charts (`charts/`)

Application Helm charts organized by functional domain:

- **`base/`** - Core cluster infrastructure (certificates, error pages, monitoring, backup, etc.)
- **`security/`** - Security components (External Secrets Operator) - deployed via base role
- **`storage/`** - Storage providers (TrueNAS, Synology) - deployed via base role when enabled
- **`tweaks/`** - Cluster configuration tweaks - deployed via base role
- **`ai/`** - AI/ML applications (LiteLLM, Ollama, Open-WebUI)
- **`home-automation/`** - IoT and home automation (EMQX, Home Assistant, Node-RED, Z-Wave JS)
- **`infrastructure/`** - Optional infrastructure (ACM, MCE, Intel GPU)
- **`media/`** - Media server applications (Plex, Sonarr, Radarr, Jellyfin, etc.)
- **`productivity/`** - Productivity tools (Terraform Enterprise, Startpunkt, etc.)
- **`radio/`** - Radio/ADSB applications

## Base Components

Each cluster type includes ApplicationSets that deploy core components from multiple chart directories:

### Core Infrastructure (`charts/base/` - via base-apps.yaml)

- **certificates** - cert-manager operator with Let's Encrypt ClusterIssuers
- **custom-error-pages** - Branded error pages for OpenShift router
- **gatus** - Health monitoring and status dashboard
- **generic-device-plugin** - Kubernetes device plugin for custom hardware
- **goldilocks** - VPA recommendations for resource optimization
- **k10-kasten-operator** - Veeam Kasten backup and disaster recovery
- **keepalived-operator** - Virtual IP management for high availability
- **openshift-nfd** - Node Feature Discovery for hardware detection
- **system-reservation** - System resource reservation via MachineConfig

### Security (`charts/security/` - via base-security.yaml)

- **external-secrets-operator** - Secret management with Infisical integration

### Storage (`charts/storage/` - via base-storage.yaml)

- **synology** - Synology NAS CSI driver (optional, disabled by default)
- **truenas** - TrueNAS CSI driver (optional, disabled by default)

### Tweaks (`charts/tweaks/` - via base-tweaks.yaml)

- **snapshot-finalizer-remover** - Cleanup utility for VolumeSnapshot finalizers
- **disable-master-secondary-interfaces** - Network interface management (optional)
- **disable-worker-secondary-interfaces** - Network interface management (optional)

Components are enabled/disabled by commenting/uncommenting entries in the ApplicationSet list generators within each cluster type's templates.

## Deployment Flow

```
cluster/
  └── Selects cluster type (hub/sno/test)
       └── roles/<type>/templates/
            ├── base-apps.yaml (core infrastructure)
            ├── base-security.yaml (external-secrets)
            ├── base-storage.yaml (TrueNAS, Synology)
            ├── base-tweaks.yaml (cluster tweaks)
            └── <domain>.yaml (ai, media, home-automation, etc.)
                 └── charts/<domain>/<app>/
```

## Adding New Applications

1. Create Helm chart under appropriate domain: `charts/<domain>/<app>/`
2. Add entry to the relevant ApplicationSet in `roles/<cluster-type>/templates/<domain>.yaml`
3. Enable/disable by uncommenting/commenting the entry in the list generator

## Key Changes from Previous Structure

- **EMQX moved** from `infrastructure` to `home-automation` (better functional grouping)
- **Base role created** to consolidate core cluster components
- **Cluster types** now properly separated from functional roles
- **Clearer separation** between cluster configuration and application deployment
