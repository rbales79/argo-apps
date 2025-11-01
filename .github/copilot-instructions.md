# AI Assistant Working Guide

Purpose: Provide just enough project-specific context so an AI agent can make correct, low‑risk changes immediately.

## Big Picture

- This repo defines an OpenShift / Argo CD GitOps model organized as: **bootstrap** (manual cluster Application) -> **roles** (Helm charts creating ApplicationSets) -> **charts** (individual app Helm charts).
- The bootstrap process creates a single Argo CD `Application` named "cluster" pointing at `roles/<cluster-name>/` (e.g., `roles/sno/`). This role Helm chart deploys **ApplicationSets** (not Applications directly) which then generate individual Applications for each app.
- Each role (e.g., `sno`, `hub`) is a complete Helm chart that creates multiple ApplicationSets grouped by function (ai, media, base, security, storage, tweaks, home-automation, productivity).
- Environments / feature differences are driven by Helm values in `roles/<cluster-name>/values.yaml` and ApplicationSet generator lists, not by Kustomize overlays.

## Key Directories

- `bootstrap/` – Contains README with manual bootstrap instructions for creating the initial "cluster" Application
- `roles/<cluster-name>/` – **One Helm chart per cluster** (e.g., `sno`, `hub`, `test`, `template`). Each folder defines ALL ApplicationSets for that specific cluster. The chart name is "cluster" but deployed with release name matching the cluster. Contains:
  - `Chart.yaml` – Defines the "cluster" chart
  - `values.yaml` – All cluster-specific configuration (domain, timezone, storage, networking, IPs, etc.)
  - `templates/*.yaml` – ApplicationSet definitions (ai.yaml, media.yaml, base-apps.yaml, etc.) that create child Applications
  - **Note:** Changes to ApplicationSet templates usually need to be replicated across all cluster roles (sno, hub, test)
- `charts/<domain>/<app>/` – Individual application Helm charts (manifests: Deployments/StatefulSets, Services, Routes, ConsoleLinks, PVCs, etc.). Organized by domain: `ai/`, `media/`, `base/`, `security/`, `storage/`, `tweaks/`, `home-automation/`, `productivity/`, `infrastructure/`, `radio/`
- `.github/instructions/adding-a-role.instructions.md` – Workflow documentation (NOTE: This is partially outdated; actual pattern uses ApplicationSets, not individual role Applications)
- `docs/` – Documentation including troubleshooting guides, standards, and reference materials (e.g., `docs/ai-stack/`)
- `scripts/` – Utility scripts for scaffolding charts, validating icons, VPA reporting, cluster cleanup, etc.

## Core Patterns

1. **ApplicationSet-Based Architecture:** Role charts create **ApplicationSets** (not Applications directly). Each ApplicationSet uses list generators to define multiple apps and creates child Applications dynamically. This allows centralized management while maintaining per-app flexibility.
2. **Single Source of Truth for Config:** Cluster-scoped configuration lives in `roles/<cluster-name>/values.yaml` under the `config:` key. This includes `cluster`, `spec`, `certificates`, `externalSecrets`, `network`, `plex`, `emqx`, etc. All ApplicationSets pass these values to child app charts via `helm.valuesObject`.
3. **App Enable/Disable:** Apps are enabled/disabled by adding/removing (or commenting) elements in the ApplicationSet's `generators.list.elements` array. Each element defines `name`, `group` (chart domain), and optional properties like `gatus.enabled`.
4. **Namespace Management:** ApplicationSets now use `managedNamespaceMetadata` to apply labels (e.g., `goldilocks.fairwinds.com/enabled: "true"`) to created namespaces. This is key for integration with operators like VPA/Goldilocks.
5. **App Chart Structure:** Each app chart should expose configurable: image (repository/tag), persistence (PVC size/class), route host (constructed from cluster top-level domain), resource requests, gatus monitoring config, and external secret references.
6. **OpenShift Integrations:** Prefer Routes over Ingress, include `Route` TLS edge termination where practical, and use ConsoleLink / homepage integration patterns. Routes use the pattern: `<app-name>.apps.<cluster-name>.<top-level-domain>`.
7. **Version Updates:** Automated (Renovate) – keep image/tag parameters in `values.yaml` with renovate comments; avoid hardcoding in manifests.
8. **Sync Waves:** ApplicationSets use annotations like `argocd.argoproj.io/sync-wave` to control deployment order (0 for security/ESO, 50 for storage, 100 for apps, 200 for tweaks).

## Adding a New Application (Agent Checklist)

1. **Choose target ApplicationSet:** Determine which functional group the app belongs to (`ai`, `media`, `base`, `home-automation`, `productivity`, `security`, `storage`, `tweaks`). Each has a corresponding ApplicationSet template (e.g., `roles/<cluster>/templates/ai.yaml`).
2. **Scaffold app Helm chart:** Create under `charts/<domain>/<app>/` (copy structure from similar existing app or use `scripts/scaffold-new-chart.sh`):
   - `Chart.yaml` – chart metadata
   - `values.yaml` – default configuration including `cluster`, `application`, `pods`, `gatus` sections
   - `templates/` – Kubernetes manifests (deployment/statefulset, service, route, PVC, ConsoleLink, etc.)
3. **Add app to ALL cluster ApplicationSets:** Edit the ApplicationSet in EACH cluster role (e.g., `roles/sno/templates/<group>.yaml`, `roles/hub/templates/<group>.yaml`, `roles/test/templates/<group>.yaml`) and add a new element to `generators.list.elements`:
   ```yaml
   - name: myapp
     group: domain # e.g., ai, media, productivity
     gatus:
       enabled: true # optional, for health monitoring
   ```
4. **Configure app chart `values.yaml`:** Include:
   - `cluster:` section (will be overridden by ApplicationSet values)
   - `application:` metadata (name, group, icon, description, port, location)
   - `pods:` image configuration with renovate comments
   - `gatus:` monitoring settings if applicable
5. **Test locally:** Run `helm template <release-name> ./roles/<cluster> -s templates/<group>.yaml` to verify the ApplicationSet generates correct Application manifests.
6. **Monitor deployment:** After commit, check `oc get applicationset -n openshift-gitops` and `oc get applications -A` to verify the app is created and syncing.

## Adding / Modifying an ApplicationSet (Summary)

- Each role directory (e.g., `roles/sno/`) contains templates for ApplicationSets organized by function:
  - `ai.yaml` – AI/ML applications
  - `media.yaml` – Media management applications
  - `base-apps.yaml`, `base-security.yaml`, `base-storage.yaml`, `base-tweaks.yaml` – Infrastructure components
  - `home-automation.yaml` – IoT and home automation
  - `productivity.yaml` – Productivity tools
  - `delay-after-security.yaml`, `delay-after-storage.yaml` – Delay jobs to ensure dependencies are ready
  - `wait-for-eso-rbac.yaml` – RBAC resources for External Secrets Operator readiness checks
- To add a new ApplicationSet category, create a new template file following the existing pattern:
  - Use `{{ .Release.Name }}-<category>` as the ApplicationSet name
  - Define `generators.list.elements` with apps in that category
  - Set appropriate `sync-wave` annotation (0=security, 50=storage, 100=apps, 200=tweaks)
  - Include `managedNamespaceMetadata` with goldilocks label if VPA recommendations are desired
  - Pass `config` values to child Applications via `helm.valuesObject`
- **Important:** When modifying ApplicationSet templates, replicate changes across all cluster roles (`sno`, `hub`, `test`) to maintain consistency

## Naming & Conventions

- **Cluster/role names:** `sno` (Single Node OpenShift), `hub` (management cluster), `test` (testing cluster), `template` (reference template) – used as release name when deploying the role chart
- **ApplicationSet names:** `<release-name>-<category>` where release-name matches the cluster (e.g., `sno-ai`, `hub-media`, `test-base`)
  - Template uses: `{{ .Release.Name }}-<category>` to generate the correct name
- **Application names:** Match the app name exactly (`litellm`, `open-webui`, `plex`, etc.)
- **App chart directories:** `charts/<domain>/<app>` where domain matches the functional category
- **Namespaces:** Automatically created per application, matching the application name
- **Routes:** Follow pattern `<app-name>.apps.<cluster-name>.<top-level-domain>`
- Avoid embedding environment names in resource names; rely on logical separation (namespaces, cluster names).

## Guardrails for Agents

- Do NOT introduce Kustomize overlays; stick to Helm + values.
- Preserve existing value keys; extend rather than rename to avoid breaking users.
- Before removing a chart or role, ensure a pruning path (role disabled) is clearly documented in PR description.
- Keep YAML indentation and style consistent with existing charts.

## Multi-Cluster Management

This workspace supports managing multiple OpenShift clusters simultaneously via cluster management functions (sourced from `.devcontainer/cluster-management.sh`).

### Available Clusters

- **sno** - Single Node OpenShift (production)
- **hub** - Hub/management cluster
- **test** - Testing cluster

### Cluster Context Commands

**CRITICAL: Always validate cluster context before troubleshooting or making changes.**

- **Switch clusters:** `hub`, `test`, or `sno` (shorthand functions)
- **Check current cluster:** `current` or `current-cluster`
- **Check all cluster status:** `status` or `cluster-status`
- **List kubeconfigs:** `clusters`

### AI Assistant Protocol

**Before executing any `oc` or `kubectl` commands:**

1. **Always check current cluster context first** using `current-cluster` or by checking `$KUBECONFIG`
2. **Confirm with user** if the target cluster is correct for the operation
3. **Warn user** if no cluster is selected or if cluster connectivity fails
4. **Suggest switching** if user's intent implies a different cluster (e.g., asking about "sno" apps while connected to "hub")

**When troubleshooting issues:**

- Run `current-cluster` to verify which cluster is active
- If operation fails with connectivity errors, run `cluster-status` to check all clusters
- Include cluster name in all diagnostic outputs: "Checking pods on **sno** cluster..."
- If user doesn't specify cluster, ask which cluster they want to investigate

**Example interaction pattern:**

```
User: "check if litellm is running"
Assistant: First, let me verify which cluster we're connected to...
[runs: current-cluster]
Assistant: We're currently on the **sno** cluster. Checking litellm status...
[runs: oc get pods -n litellm]
```

### Multi-Cluster Context Validation

When user requests operations that could affect multiple clusters:

- **Explicitly state** which cluster will be affected
- **Ask for confirmation** before making changes across clusters
- **Use cluster-specific commands** when iterating (e.g., save/restore `$KUBECONFIG`)

## Typical Commands (for human validation)

- **Render ApplicationSet for a cluster:** `helm template <cluster-name> ./roles/<cluster> -s templates/<category>.yaml`
- **Render all resources:** `helm template <cluster-name> ./roles/<cluster>`
- **Lint an app chart:** `helm lint charts/<domain>/<app>`
- **Check ApplicationSets:** `oc get applicationset -n openshift-gitops`
- **Check Applications:** `oc get applications -A`
- **Check app status:** `oc get pods -n <app-name>`

## When User Says… (Trigger Mapping)

- "add a chart" / "create a chart" → follow `.github/instructions/adding-a-role.instructions.md` (note: this is partially outdated)
- "add app <name>" → perform application checklist above (add to appropriate ApplicationSet)
- "troubleshoot <app>" → **FIRST run `current-cluster` to validate context**, then check pod logs, route configuration, external secrets, PVC status
- "check <app>" / "is <app> running" → **FIRST run `current-cluster`**, then check pod status
- "switch to <cluster>" / "use <cluster>" → run appropriate cluster switch command (`hub`, `test`, or `sno`)
- "what cluster am I on" / "current cluster" → run `current-cluster`
- "show all clusters" / "cluster status" → run `cluster-status`
- "fix Home Assistant 400 error" or similar reverse proxy issues → check HTTP config for `use_x_forwarded_for` and `trusted_proxies`
- Any `oc` or `kubectl` command request → **FIRST verify cluster context with `current-cluster`**, confirm with user if needed

## Common Pitfalls

- **Not validating cluster context:** ALWAYS run `current-cluster` before executing `oc`/`kubectl` commands. Troubleshooting the wrong cluster wastes time and can cause confusion.
- **Forgetting to add app to ApplicationSet:** New apps won't be deployed unless added to the appropriate `generators.list.elements` in the ApplicationSet template.
- **Only updating one cluster role:** Changes to ApplicationSets need to be made in ALL cluster roles (sno, hub, test) unless the change is truly cluster-specific.
- **Hardcoding domain:** Always use `{{ .Values.cluster.top_level_domain }}` or similar value references instead of hardcoding domains.
- **Missing `spec.source.targetRevision`:** Ensure ApplicationSets use `targetRevision: HEAD` or specific branch/tag consistently.
- **ResourceVersion conflicts:** When ApplicationSets fail to sync with "metadata.resourceVersion: Invalid value: 0x0" errors, delete and recreate the ApplicationSet (Argo CD will regenerate child Applications).
- **Home Assistant reverse proxy errors:** OpenShift Routes require Home Assistant to trust proxy headers. Add HTTP config with `use_x_forwarded_for: true` and `trusted_proxies` for pod/service networks (10.128.0.0/14, 172.30.0.0/16).
- **Missing managedNamespaceMetadata:** New ApplicationSets should include `managedNamespaceMetadata.labels` for Goldilocks/VPA integration.
- **Incorrect sync-wave:** Security/ESO must be wave 0, storage wave 50, apps wave 100, tweaks wave 200.

Keep responses concise and reference concrete file paths for edits.
