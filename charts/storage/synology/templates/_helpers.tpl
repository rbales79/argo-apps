{{/*
Ensure storage class has required name field
*/}}
{{- define "democratic-csi-synology.storageClass" -}}
{{- $storageClass := index .Values "democratic-csi" "storageClasses" 0 -}}
{{- if not $storageClass.name -}}
{{- $_ := set $storageClass "name" "synology-iscsi" -}}
{{- end -}}
{{- end -}}

{{/*
Call this template to ensure storage classes are properly configured
*/}}
{{- define "democratic-csi-synology.validateStorageClasses" -}}
{{- if (index .Values "democratic-csi" "storageClasses") -}}
{{- include "democratic-csi-synology.storageClass" . -}}
{{- end -}}
{{- end -}}
