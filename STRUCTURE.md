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

- **`ai/`** - AI/ML applications (LiteLLM, Ollama, Open-WebUI)
- **`home-automation/`** - IoT and home automation (EMQX, Home Assistant, Node-RED)
- **`infrastructure/`** - Core infrastructure (certificates, Kasten, Goldilocks, Gatus)
- **`media/`** - Media server applications (Plex, Sonarr, Radarr, etc.)
- **`productivity/`** - Productivity tools (Terraform Enterprise, Startpunkt, etc.)
- **`radio/`** - Radio/ADSB applications
- **`security/`** - Security tools (External Secrets Operator)
- **`storage/`** - Storage providers (TrueNAS, Synology)
- **`tweaks/`** - Cluster configuration tweaks

## Base Components

All cluster types inherit these core components from the `base` role:

- **External Secrets Operator** - Secret management with Infisical
- **Keepalived Operator** - Virtual IP management
- **Certificates** - cert-manager with Let's Encrypt
- **Kasten K10** - Backup and disaster recovery
- **Goldilocks** - VPA recommendations
- **Gatus** - Health monitoring
- **Custom Error Pages** - Branded error pages
- **Generic Device Plugin** - Hardware device support
- **OpenShift NFD** - Node Feature Discovery

Base components can be selectively enabled/disabled per cluster type via the role's values.

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
