#!/usr/bin/env bash
set -euo pipefail

# Scaffold a new application chart by copying charts/media/sonarr and customizing.
# This creates the chart structure but you must manually add it to ApplicationSet templates.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
SRC_CHART_DIR="$ROOT_DIR/charts/media/sonarr"

if [[ ! -d "$SRC_CHART_DIR" ]]; then
  echo "Source chart not found: $SRC_CHART_DIR" >&2
  exit 1
fi

echo "=========================================="
echo "New Application Chart Scaffolding Wizard"
echo "=========================================="
echo ""
echo "This will create a new Helm chart based on the Sonarr template."
echo "You'll be asked for:"
echo "  • Functional group (ai, media, productivity, etc.)"
echo "  • App name (machine-readable, lowercase)"
echo "  • Display name (human-readable)"
echo "  • Description, icon, and image URL"
echo "  • Container image details"
echo ""
echo "⚠️  Note: After scaffolding, you must manually add the app to"
echo "    ApplicationSet templates in roles/sno/, roles/hub/, roles/test/"
echo ""
echo "Press Ctrl+C to cancel at any time."
echo ""

# Ask for the group first
echo "Available functional groups:"
ls -1 "$ROOT_DIR/charts/" | sed 's/^/  - /'
echo ""
read -rp "Which group will this chart belong to? " CHART_GROUP
if [[ -z "${CHART_GROUP}" ]]; then
  echo "Chart group is required." >&2
  exit 1
fi

# Validate that the group exists
if [[ ! -d "$ROOT_DIR/charts/$CHART_GROUP" ]]; then
  echo "Group '$CHART_GROUP' does not exist in charts/ directory." >&2
  echo "Available groups: $(ls -1 "$ROOT_DIR/charts/" | tr '\n' ' ')" >&2
  exit 1
fi

read -rp "New chart machine name (lowercase, no spaces, e.g. 'readarr'): " CHART_NAME
if [[ -z "${CHART_NAME}" ]]; then
  echo "Chart name is required." >&2
  exit 1
fi

if [[ "$CHART_NAME" =~ [A-Z\ ] ]]; then
  echo "Chart name must be lowercase and contain no spaces." >&2
  exit 1
fi

TARGET_CHART_DIR="$ROOT_DIR/charts/$CHART_GROUP/$CHART_NAME"
if [[ -e "$TARGET_CHART_DIR" ]]; then
  echo "Target chart already exists: $TARGET_CHART_DIR" >&2
  exit 1
fi

DEFAULT_DISPLAY_NAME="$(echo "$CHART_NAME" | sed -E 's/(^|[-_])(\w)/\U\2/g')"
read -rp "Display name (Application.name) [${DEFAULT_DISPLAY_NAME}]: " DISPLAY_NAME
DISPLAY_NAME=${DISPLAY_NAME:-$DEFAULT_DISPLAY_NAME}

read -rp "Description: " DESCRIPTION || true

# Set app group based on selected chart group with capitalization
DEFAULT_APP_GROUP="$(echo "$CHART_GROUP" | sed -E 's/(^|[-_])(\w)/\U\2/g')"
read -rp "App group (Application.group) [${DEFAULT_APP_GROUP}]: " APP_GROUP
APP_GROUP=${APP_GROUP:-$DEFAULT_APP_GROUP}

echo ""
echo "Icon options:"
echo "  - Material Design Icons: mdi:icon-name (e.g., 'mdi:download', 'mdi:television')"
echo "  - Simple Icons: simple-icons:brand (e.g., 'simple-icons:docker', 'simple-icons:kubernetes')"
echo "  - CBI Icons: cbi:app-name (e.g., 'cbi:sonarr', 'cbi:radarr')"
read -rp "Console icon (Application.icon): " ICON || true

read -rp "Icon color (Application.iconColor, optional, e.g., 'blue', '#FF5733'): " ICON_COLOR || true

read -rp "Console image URL (Application.image, full URL to logo PNG/SVG): " APP_IMAGE_URL || true

read -rp "Service port (Application.port) [8989]: " PORT
PORT=${PORT:-8989}

read -rp "Container image repository (pods.main.image.repository), e.g. ghcr.io/home-operations/readarr: " CONTAINER_REPO
if [[ -z "${CONTAINER_REPO}" ]]; then
  echo "Container image repository is required." >&2
  exit 1
fi

read -rp "Container image tag (pods.main.image.tag), e.g. 1.0.0: " CONTAINER_TAG
if [[ -z "${CONTAINER_TAG}" ]]; then
  echo "Container image tag is required." >&2
  exit 1
fi

echo "Creating chart at $TARGET_CHART_DIR ..."
cp -R "$SRC_CHART_DIR" "$TARGET_CHART_DIR"

# Update Chart.yaml
CHART_FILE="$TARGET_CHART_DIR/Chart.yaml"
sed -i \
  -e "s/^name: .*/name: ${CHART_NAME}/" \
  -e "s/^description: .*/description: A Helm chart for ${DISPLAY_NAME}/" \
  "$CHART_FILE"

# Rebuild values.yaml: keep cluster: block from source, then write new application and pods blocks.
SRC_VALUES="$SRC_CHART_DIR/values.yaml"
TARGET_VALUES="$TARGET_CHART_DIR/values.yaml"

{
  # Extract cluster block from source up to (but not including) 'application:'
  awk 'BEGIN{print_mode=1} /^application:[[:space:]]*$/ {print_mode=0} print_mode==1 {print $0}' "$SRC_VALUES"
  echo "application:"
  echo "  name: ${DISPLAY_NAME}"
  echo "  group: ${APP_GROUP}"
  echo "  icon: ${ICON}"
  echo "  iconColor: \"${ICON_COLOR}\""
  echo "  image: \"${APP_IMAGE_URL}\""
  echo "  description: \"${DESCRIPTION//"/\\"}\""
  echo "  port: ${PORT}"
  echo "  location: 0"
  echo ""
  echo "pods:"
  echo "  main:"
  echo "    image:"
  echo "      repository: ${CONTAINER_REPO}"
  echo "      # renovate: datasource=docker depName=${CONTAINER_REPO} versioning=semver"
  echo "      tag: ${CONTAINER_TAG}"
  echo "      pullPolicy: IfNotPresent"
} > "$TARGET_VALUES.tmp"

mv "$TARGET_VALUES.tmp" "$TARGET_VALUES"

# Add gatus section if not present
if ! grep -q "^gatus:" "$TARGET_VALUES"; then
  echo "" >> "$TARGET_VALUES"
  echo "# Gatus monitoring" >> "$TARGET_VALUES"
  echo "gatus:" >> "$TARGET_VALUES"
  echo "  enabled: true" >> "$TARGET_VALUES"
  echo "  interval: 5m" >> "$TARGET_VALUES"
  echo "  conditions:" >> "$TARGET_VALUES"
  echo "    - \"[STATUS] == 200\"" >> "$TARGET_VALUES"
  echo "    - \"[RESPONSE_TIME] < 3000\"" >> "$TARGET_VALUES"
fi

echo ""
echo "Chart scaffolding complete at: charts/${CHART_GROUP}/${CHART_NAME}"
echo ""
echo "⚠️  IMPORTANT: You must now add this app to ApplicationSet templates ⚠️"
echo ""
echo "Add the following to the 'elements' list in these files:"
echo "  - roles/sno/templates/${CHART_GROUP}.yaml"
echo "  - roles/hub/templates/${CHART_GROUP}.yaml"
echo "  - roles/test/templates/${CHART_GROUP}.yaml"
echo ""
echo "Add this entry:"
echo "          - name: ${CHART_NAME}"
echo "            group: ${CHART_GROUP}"
if [[ -n "${ICON}" ]]; then
  echo "            gatus:"
  echo "              enabled: true"
fi
echo ""
echo "Example location in the file:"
echo "    generators:"
echo "      - list:"
echo "          elements:"
echo "            - name: existing-app"
echo "              group: ${CHART_GROUP}"
echo "            - name: ${CHART_NAME}  # ← ADD THIS"
echo "              group: ${CHART_GROUP}"
if [[ -n "${ICON}" ]]; then
  echo "              gatus:"
  echo "                enabled: true"
fi
echo ""
echo "💡 Tip: Search for '${CHART_GROUP}.yaml' in the roles directory to find all templates"
