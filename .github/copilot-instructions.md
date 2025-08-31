# AI Assistant Working Guide

Purpose: Provide just enough project-specific context so an AI agent can make correct, low‑risk changes immediately.

## Big Picture
- This repo defines an OpenShift / Argo CD GitOps model organized as: `cluster` (bootstrap) -> `roles` (functional bundles) -> `charts` (individual app Helm charts).
- Argo CD deploys a single "cluster" Application (or ApplicationSet) which then instantiates Applications per enabled role. Each role chart installs Argo CD Application CRs that point at the app Helm charts under `charts/`.
- Environments / feature differences are driven by Helm values (via `cluster/values.yaml`) and role enablement flags, not by Kustomize overlays.

## Key Directories
- `cluster/` – Top-level chart; `values.yaml` drives which roles are enabled and cluster metadata (domain, timezone, admin email, etc.).
- `roles/<role>/` – A Helm chart per functional domain. `templates/*.yaml` define Argo CD Applications for the apps in that role. Role enablement toggled via `roles.<role>.enabled` in `cluster/values.yaml`.
- `charts/<domain>/<app>/` – Individual application Helm charts (manifests: Deployments/StatefulSets, Services, Routes, ConsoleLinks, PVCs, etc.).
- `.github/instructions/adding-a-role.instructions.md` – Canonical workflow for adding a role (agent should follow when user asks to add/create a role).
- `docs/` – Supplemental diagrams / images.

## Core Patterns
1. **Role Aggregation via Helm:** Roles are themselves Helm charts whose templates create Argo CD Application (CR) objects referencing specific app charts.
2. **Single Source of Truth for Config:** Cluster-scoped configuration and role toggles live in `cluster/values.yaml`. Do not duplicate these values inside role or app charts—read them as Helm values if required (extend parent values propagation if needed).
3. **Idempotent Enable/Disable:** Setting `roles.<name>.enabled: "false"` must result in removal (prune) of that role's Applications; adding or flipping to true deploys them.
4. **App Chart Structure:** Each app chart should expose configurable: image (repository/tag), persistence (PVC size/class), route host (constructed from cluster top-level domain), resource requests, and any external secret references (if applicable).
5. **OpenShift Integrations:** Prefer Routes over Ingress, include `Route` TLS edge termination where practical, and use ConsoleLink / homepage integration patterns where already present in existing charts (mirror style from existing AI or media apps).
6. **Version Updates:** Automated (Renovate) – keep image/tag parameters in `values.yaml` or chart defaults; avoid hardcoding in manifests.

## Adding a New Application (Agent Checklist)
1. Choose target role (create new one only if functional grouping is distinct). If new role: follow `.github/instructions/adding-a-role.instructions.md`.
2. Scaffold app Helm chart under `charts/<role-or-domain>/<app>/` (copy minimal structure from a similar existing app: `Chart.yaml`, `values.yaml`, `templates/deployment.yaml`, `templates/service.yaml`, `templates/route.yaml` if HTTP, plus optional PVC / ConsoleLink).
3. In the role chart `roles/<role>/templates/`, add an Argo CD `Application` manifest referencing the new app chart path and consuming relevant values. Keep naming convention: `metadata.name: <app>` (unique per namespace) and `spec.source.path: charts/<role-or-domain>/<app>`.
4. Expose user-configurable settings in the app chart `values.yaml` (image, persistence, host, replicas, resources).
5. Wire any cluster-wide parameters by referencing role values that bubble up from the cluster chart (add values keys if absent).
6. Update `cluster/values.yaml` if new role OR to supply initial app configuration (only if cluster-level override necessary).
7. Validate with a Helm template dry-run (locally) and ensure Argo CD Application spec fields mirror existing patterns.

## Adding / Modifying a Role (Summary)
- Role dir: `roles/<name>/` contains `Chart.yaml` + `templates/*.yaml` (Applications). Each template should guard creation with a Helm `if` tied to role enablement only at the cluster chart layer (cluster chart handles enabling/disabling entire role—individual app gating inside a role should be rare; prefer role-scope simplicity).
- Update `cluster/values.yaml` roles list / enable flag.

## Naming & Conventions
- Roles: lowercase functional name (`ai`, `media`, `utilities`).
- App chart directories: `charts/<role>/<app>`.
- Argo CD Application names: match app (`openwebui`, `litellm`, etc.).
- Avoid embedding environment names in resource names; rely on logical separation (namespaces, charts).

## Guardrails for Agents
- Do NOT introduce Kustomize overlays; stick to Helm + values.
- Preserve existing value keys; extend rather than rename to avoid breaking users.
- Before removing a chart or role, ensure a pruning path (role disabled) is clearly documented in PR description.
- Keep YAML indentation and style consistent with existing charts.

## Typical Commands (for human validation)
- Render cluster chart: `helm template cluster/ -f cluster/values.yaml` (ensure Applications referencing new app appear when enabled).
- Lint a chart: `helm lint charts/<role>/<app>`.

## When User Says… (Trigger Mapping)
- "add a role" / "create role" → follow `.github/instructions/adding-a-role.instructions.md`.
- "add app <name> to <role>" → perform application checklist above.

## Common Pitfalls
- Forgetting to add new role to `cluster/values.yaml` → role Applications never created.
- Hardcoding domain instead of using `config.cluster.top_level_domain`.
- Missing `spec.source.targetRevision` alignment with cluster chart (ensure consistent branch/tag).

Keep responses concise and reference concrete file paths for edits.
