# OpenShift Argo CD Cluster Deployment Model

This repository implements an Argo CD-based GitOps deployment model for OpenShift/OKD clusters. It provides a structured approach to deploying and managing applications across different functional domains through a simplified template-based system.

## Architecture Overview

This repository uses an **ApplicationSet-based GitOps architecture**:

- **Bootstrap** (manual): Create one Argo CD `Application` named "cluster" pointing to `roles/<cluster-name>/`
- **Roles** (Helm charts): Each cluster role (sno, hub, test, template) is a complete Helm chart that deploys **ApplicationSets**
- **ApplicationSets**: Each functional group (ai, media, security, etc.) is an ApplicationSet that generates child Applications
- **Charts**: Individual application Helm charts in `charts/<domain>/<app>/`

![Hierarchy](docs/images/chart-hierarchy.png)

## Repository Structure

```text
├── bootstrap/                 # Bootstrap instructions and documentation
│   └── README.md              # Step-by-step cluster setup guide
├── roles/                     # Cluster role definitions (Helm charts)
│   ├── sno/                   # Single Node OpenShift configuration
│   │   ├── Chart.yaml         # Chart metadata
│   │   ├── values.yaml        # Cluster-specific configuration
│   │   └── templates/         # ApplicationSet definitions
│   │       ├── ai.yaml        # AI/ML applications ApplicationSet
│   │       ├── media.yaml     # Media applications ApplicationSet
│   │       ├── base-apps.yaml # Core cluster services ApplicationSet
│   │       ├── home-automation.yaml  # IoT/Smart Home ApplicationSet
│   │       ├── productivity.yaml     # Productivity tools ApplicationSet
│   │       └── ...
│   ├── hub/                   # Hub/management cluster configuration
│   ├── test/                  # Testing cluster configuration
│   └── template/              # Reference template for new clusters
└── charts/                    # Individual application Helm charts
    ├── ai/
    │   ├── litellm/           # LiteLLM proxy for LLM management
    │   ├── ollama/            # Local LLM runtime
    │   └── open-webui/        # Web UI for LLMs
    ├── infrastructure/
  │   ├── gatus/             # Service monitoring and health checks
  │   ├── goldilocks/        # VPA recommendations dashboard
  │   ├── democratic-csi-synology-iscsi/ # Synology iSCSI storage driver
  │   └── democratic-csi-synology-nfs/   # Synology NFS storage driver
    ├── media/
    │   ├── bazarr/            # Subtitle management
    │   ├── flaresolverr/      # Cloudflare proxy solver
    │   ├── gaps/              # Media gap detection
    │   ├── huntarr/           # Wanted movie management
    │   ├── kapowarr/          # Comic book management
    │   ├── kavita/            # Digital library and comic reader
    │   ├── lidarr/            # Music collection management
    │   ├── metube/            # YouTube downloader web UI
    │   ├── overseerr/         # Media request management
    │   ├── pinchflat/         # YouTube channel archiver
    │   ├── plex/              # Media server
    │   ├── prowlarr/          # Indexer management
    │   ├── radarr/            # Movie collection management
    │   ├── readarr/           # Book and audiobook management
    │   ├── sabnzbd/           # Usenet downloader
    │   ├── sonarr/            # TV series management
    │   └── tautulli/          # Plex analytics and monitoring
    ├── productivity/
    │   ├── bookmarks/         # Bookmark management
    │   ├── cyberchef/         # Data manipulation toolkit
    │   ├── excalidraw/        # Whiteboard and diagramming
    │   ├── it-tools/          # Collection of IT utilities
    │   └── startpunkt/        # Homepage and dashboard
    └── security/
        └── external-secrets-operator/ # External secrets management
```

## How It Works

### 1. Bootstrap Process

The bootstrap creates a single Argo CD `Application` named "cluster" that points to `roles/<cluster-name>/`:

```bash
oc apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cluster
  namespace: openshift-gitops
spec:
  source:
    path: roles/sno  # or roles/hub, roles/test, etc.
    repoURL: https://github.com/YOUR_USERNAME/argo-apps
    targetRevision: HEAD
  # ... (see bootstrap/README.md for complete example)
EOF
```

### 2. Role Deployment

Each role folder (`sno`, `hub`, `test`, `template`) is a Helm chart that creates ApplicationSets:

**Key file**: `roles/<cluster-name>/values.yaml`

- Contains cluster-wide configuration (domain, timezone, storage, networking)
- Passed to all ApplicationSets via `helm.valuesObject`
- Applications inherit these values automatically

**ApplicationSet Templates**: `roles/<cluster-name>/templates/`

- **base-security.yaml** (sync-wave: 0): External Secrets Operator, RBAC resources
- **base-storage.yaml** (sync-wave: 50): TrueNAS CSI, Synology CSI providers
- **ai.yaml** (sync-wave: 100): AI/ML applications (LiteLLM, Ollama, Open-WebUI)
- **media.yaml** (sync-wave: 100): Media management applications
- **home-automation.yaml** (sync-wave: 100): IoT and smart home applications
- **productivity.yaml** (sync-wave: 100): Productivity and utility tools
- **base-tweaks.yaml** (sync-wave: 200): Cluster optimizations and cleanup jobs

### 3. ApplicationSet Pattern

Each ApplicationSet uses a list generator to define multiple applications:

```yaml
spec:
  generators:
    - list:
        elements:
          - name: litellm
            group: ai
            gatus:
              enabled: true
          - name: open-webui
            group: ai
```

The ApplicationSet template creates a child Application for each element, pointing to `charts/<group>/<name>/`.

### 4. Application Deployment

Each application in `charts/<domain>/<app>/` is a complete Helm chart with:

- **Kubernetes manifests**: Deployments/StatefulSets, Services, PVCs
- **OpenShift resources**: Routes (with TLS), ConsoleLinks
- **Monitoring integration**: Gatus health checks
- **Resource management**: VPA-compatible via namespace labels
- **Storage options**: Configurable PVC size and storage class

## Available Applications

### AI/ML Applications (`charts/ai/`)

- **LiteLLM**: Unified API proxy for managing multiple LLM providers
- **Ollama**: Local large language model runtime
- **Open WebUI**: User-friendly web interface for interacting with LLMs

### Base/Infrastructure Applications (`charts/base/`)

- **Certificates**: Certificate management for cluster TLS
- **Custom Error Pages**: Custom error pages for ingress/routes
- **Gatus**: Service monitoring and health checks with status page
- **Generic Device Plugin**: Kubernetes device plugin for custom resources
- **Goldilocks**: VPA (Vertical Pod Autoscaler) recommendations dashboard
- **K10 Kasten Operator**: Backup and disaster recovery operator
- **Keepalived Operator**: Virtual IP management for high availability
- **OpenShift NFD**: Node Feature Discovery for hardware detection
- **System Reservation**: Resource reservation for system workloads
- **Vertical Pod Autoscaler**: Automatic container resource recommendations

### Home Automation Applications (`charts/home-automation/`)

- **EMQX Operator**: MQTT broker operator for IoT messaging
- **Home Assistant**: Open-source home automation platform
- **Node-RED**: Flow-based development tool for IoT
- **Zwavejs2MQTT**: Z-Wave to MQTT gateway

### Infrastructure Applications (`charts/infrastructure/`)

- **Advanced Cluster Management**: Multi-cluster management for OpenShift
- **Intel GPU Operator**: Intel GPU support for AI/ML workloads
- **Multicluster Engine**: Engine for managing multiple clusters

### Media Applications (`charts/media/`)

- **Bazarr**: Subtitle management for movies and TV shows
- **FlareSolverr**: Cloudflare proxy solver for web scraping
- **Gaps**: Tool for finding missing movies in collections
- **Huntarr**: Wanted movie management and automation
- **Jellyfin**: Free software media system (Plex alternative)
- **Jellyseerr**: Media request management for Jellyfin
- **Kapowarr**: Comic book collection management
- **Kavita**: Digital library server and comic/book reader
- **Lidarr**: Music collection management and automation
- **Metube**: Web-based YouTube downloader
- **Overseerr**: Media request management for Plex users
- **Pinchflat**: YouTube channel archiver and downloader
- **Plex**: Media server for streaming movies, TV shows, and music
- **Posterizarr**: Automated poster management for media libraries
- **Prowlarr**: Indexer management for \*arr applications
- **Radarr**: Movie collection management and automation
- **Readarr**: Book and audiobook collection management
- **Recyclarr**: TRaSH Guides automation for \*arr applications
- **SABnzbd**: Usenet newsreader and downloader
- **Sonarr**: TV series collection management and automation
- **Tautulli**: Plex media server analytics and monitoring

### Productivity Applications (`charts/productivity/`)

- **Bookmarks**: Web bookmark management service
- **CyberChef**: Data manipulation and analysis toolkit
- **Excalidraw**: Collaborative whiteboard and diagramming tool
- **IT-Tools**: Collection of handy IT utilities and converters
- **Startpunkt**: Customizable homepage and application dashboard
- **Terraform Enterprise**: Private Terraform Cloud alternative

### Radio Applications (`charts/radio/`)

- **ADSB**: ADS-B aircraft tracking receiver and aggregator

### Security Applications (`charts/security/`)

- **External Secrets Operator**: Kubernetes operator for managing external secrets from providers like Infisical, AWS Secrets Manager, etc.

### Storage Applications (`charts/storage/`)

- **Synology CSI**: CSI driver for Synology NAS storage (iSCSI/NFS)
- **TrueNAS CSI**: CSI driver for TrueNAS storage (iSCSI/NFS)

### Tweaks/Optimizations (`charts/tweaks/`)

- **Disable Master Secondary Interfaces**: Removes unused network interfaces on control plane nodes
- **Disable Worker Secondary Interfaces**: Removes unused network interfaces on worker nodes
- **Snapshot Finalizer Remover**: Cleanup job for stuck VolumeSnapshot finalizers

## Getting Started

See the **[Bootstrap README](bootstrap/README.md)** for complete step-by-step instructions.

Quick start:

1. Install OpenShift GitOps operator
2. Grant Argo CD cluster-admin permissions
3. Create the cluster Application pointing to your chosen role
4. Monitor ApplicationSet and Application creation
5. Access apps via Routes: `<app-name>.apps.<cluster-name>.<domain>`

## Configuration

### Cluster Configuration

Configuration is managed via Helm values in `roles/<cluster-name>/values.yaml`:

```yaml
config:
  cluster:
    top_level_domain: roybales.com
    name: sno
    admin_email: admin@example.com
    timezone: America/New_York
    storage:
      truenas:
        zfs:
          datasetParentName: "volume1/iscsi/sno/vols"
        iscsi:
          namePrefix: "sno-"
      config:
        storageClassName: truenas-iscsi
      media:
        nfs:
          server: truenas.example.com
          path: /mnt/volume1/media

  plex:
    network:
      ip: 192.168.1.200

  certificates:
    letsencrypt:
      issuer: production

  externalSecrets:
    secret: infisical-auth-secret
    infisical:
      projectSlug: hub
      environmentSlug: prod
```

### Enabling/Disabling Applications

Edit the ApplicationSet templates in `roles/<cluster-name>/templates/` to control which apps are deployed:

```yaml
# roles/sno/templates/ai.yaml
spec:
  generators:
    - list:
        elements:
          - name: litellm # Enabled
            group: ai
          - name: open-webui # Enabled
            group: ai
          # - name: jupyter-hub  # Disabled (commented out)
          #   group: ai
```

## OpenShift Integration Features

### Networking

- **Routes**: Automatic HTTPS routes with edge termination
- **Services**: ClusterIP services for internal communication

### UI Integration

- **Console Links**: Applications appear in OpenShift console menus
- **Cluster Homepage**: Startpunkt is used as the cluster homepage and every application is listed there

### Storage

- **Flexible storage**: Uses the default cluster CSI driver unless a different one is specified
- **NFS integration**: Shared storage for media applications via NFS
- **Backup annotations**: Kasten backup integration

## Customization

### Adding a New Application

See **[Adding Applications Guide](.github/instructions/adding-a-role.instructions.md)** for detailed instructions.

Quick steps:

1. Choose the appropriate functional group (ai, media, home-automation, productivity, etc.)
2. Create a new Helm chart in `charts/<domain>/<app>/`
3. Add the app to ApplicationSet generators in **ALL** cluster roles:
   - `roles/sno/templates/<group>.yaml`
   - `roles/hub/templates/<group>.yaml`
   - `roles/test/templates/<group>.yaml`
4. Commit and push - Argo CD will sync automatically

**Scaffold script available:**

```bash
./scripts/scaffold-new-chart.sh
```

### Adding a New ApplicationSet Category

To create an entirely new functional group (rare):

1. Create ApplicationSet templates in ALL cluster roles:
   - `roles/sno/templates/<category>.yaml`
   - `roles/hub/templates/<category>.yaml`
   - `roles/test/templates/<category>.yaml`
2. Follow the existing pattern with appropriate sync-wave annotation:
   - Wave 0: Security/secrets management
   - Wave 50: Storage providers
   - Wave 100: Applications
   - Wave 200: Tweaks and optimizations
3. Create corresponding subdirectory in `charts/<category>/`

## Scripts and Tools

### VPA Goldilocks Reporter

A comprehensive Python script for analyzing VPA (Vertical Pod Autoscaler) recommendations from Goldilocks and generating detailed resource configuration reports.

**Features:**

- Multiple output formats: Console, JSON, YAML, HTML, kubectl patches
- Namespace filtering and comprehensive resource analysis
- Comparison between current and recommended configurations
- Ready-to-use kubectl patch commands for applying recommendations

**Usage:**

```bash
# Install dependencies
pip install -r scripts/requirements.txt

# Generate console report
./scripts/vpa-goldilocks-reporter.py

# Generate HTML report for media namespace
./scripts/vpa-goldilocks-reporter.py --format html --namespace media --output report.html

# Generate kubectl patches
./scripts/vpa-goldilocks-reporter.py --format kubectl --output apply-recommendations.sh
```

See [`scripts/README-vpa-goldilocks-reporter.md`](scripts/README-vpa-goldilocks-reporter.md) for complete documentation.

## Maintenance

- **Automated Updates**: Renovate monitors and updates application image versions
- **Sync Policy**: Applications are configured with automated sync (prune + selfHeal)
- **Health Monitoring**: Gatus provides real-time application health checks
- **Resource Optimization**: Goldilocks/VPA provides resource recommendations

## Documentation

- **[Bootstrap Guide](bootstrap/README.md)**: Complete cluster setup instructions
- **[Adding Applications](.github/instructions/adding-a-role.instructions.md)**: Step-by-step guide for adding new apps
- **[Architecture Guide](.github/copilot-instructions.md)**: Detailed architecture and patterns
- **[AI Stack Recommendations](docs/ai-stack/recommended-tools.md)**: Recommended AI/ML tools to add
- **[TrueNAS CSI Troubleshooting](docs/truenas-csi-troubleshooting.md)**: Storage troubleshooting guide

## Developer Notes

### Validations

Run validations using Task:

```bash
# Run all validations (ADR checks and Helm template/lint)
task validate:all

# Run only Helm validations
task validate:helm

# Run ADR validation
task validate:adr
```

The CI pipeline runs `validate:all` on pushes and PRs.

### Pre-commit Hooks

Local hooks run ADR validation and Helm validation/lint:

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Ensure helm and task are in your PATH
which helm task
```

### Tools Required

- `helm` - Chart templating and linting
- `task` - Task runner
- `oc` or `kubectl` - Kubernetes CLI
- `python3` - For scripts (with requirements.txt installed)
