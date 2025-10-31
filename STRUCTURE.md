# Repository Structure

This repository uses a GitOps approach with Argo CD to manage OpenShift cluster configurations.

## Architecture

The repository is organized into three main layers:

### 1. Cluster Bootstrap (`cluster/`)

Entry point for cluster deployment. Defines which cluster type to deploy (hub, sno, or test).

### 2. Cluster Types (`roles/`)

Cluster-specific configurations that define which functional roles are enabled:

- **`hub/`** - Full-featured hub cluster with all roles enabled
- **`sno/`** - Single Node OpenShift with resource-optimized settings
- **`test/`** - Minimal test cluster for development
- **`base/`** - Core components required by all cluster types

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

The base role deploys core components from multiple chart directories:

### Core Infrastructure (`charts/base/`)

- **certificates** - cert-manager operator with Let's Encrypt ClusterIssuers
- **custom-error-pages** - Branded error pages for OpenShift router
- **gatus** - Health monitoring and status dashboard
- **generic-device-plugin** - Kubernetes device plugin for custom hardware
- **goldilocks** - VPA recommendations for resource optimization
- **k10-kasten-operator** - Veeam Kasten backup and disaster recovery
- **keepalived-operator** - Virtual IP management for high availability
- **openshift-nfd** - Node Feature Discovery for hardware detection
- **system-reservation** - System resource reservation via MachineConfig

### Security (`charts/security/`)

- **external-secrets-operator** - Secret management with Infisical integration

### Storage (`charts/storage/`)

- **synology** - Synology NAS CSI driver (optional, disabled by default)
- **truenas** - TrueNAS CSI driver (optional, disabled by default)

### Tweaks (`charts/tweaks/`)

- **snapshot-finalizer-remover** - Cleanup utility for VolumeSnapshot finalizers
- **disable-master-secondary-interfaces** - Network interface management (optional)
- **disable-worker-secondary-interfaces** - Network interface management (optional)

All components can be selectively enabled/disabled per cluster type via the base role's values.

## Deployment Flow

```
cluster/
  └── Selects cluster type (hub/sno/test)
       └── roles/<type>/
            ├── base (core components)
            ├── security (external-secrets, keepalived)
            ├── storage (TrueNAS, Synology)
            └── functional roles (ai, media, home-automation, etc.)
                 └── charts/<domain>/<app>/
```

## Adding New Applications

1. Create Helm chart under appropriate domain: `charts/<domain>/<app>/`
2. Add Application reference to the relevant role's ApplicationSet
3. Enable/disable via cluster type values

## Key Changes from Previous Structure

- **EMQX moved** from `infrastructure` to `home-automation` (better functional grouping)
- **Base role created** to consolidate core cluster components
- **Cluster types** now properly separated from functional roles
- **Clearer separation** between cluster configuration and application deployment
