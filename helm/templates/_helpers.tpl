{{/*
Expand the name of the chart with optional prefix.*/}}
{{- define "ec2-runner.name" -}}
{{- if .Values.prefix -}}
{{- printf "%s-%s" .Values.prefix (.Chart.Name | trunc 63 | trimSuffix "-") | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Create a default fully qualified app name with optional prefix.*/}}
{{- define "ec2-runner.fullname" -}}
{{- if .Values.prefix -}}
{{- printf "%s-%s-%s" .Values.prefix .Release.Name (include "ec2-runner.name" .) | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "ec2-runner.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
