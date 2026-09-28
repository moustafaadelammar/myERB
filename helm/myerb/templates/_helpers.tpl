{{- define "myerb.name" -}}
myerb
{{- end }}

{{- define "myerb.fullname" -}}
{{ .Release.Name }}-myerb
{{- end }}
