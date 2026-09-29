{{- define "web.name" -}}web{{- end -}}

{{- define "web.fullname" -}}
{{- printf "%s-web" .Values.env | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "web.labels" -}}
app.kubernetes.io/name: web
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: rafael-interview
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
env: {{ .Values.env }}
{{- end -}}

{{- define "web.selectorLabels" -}}
app.kubernetes.io/name: web
{{- end -}}
