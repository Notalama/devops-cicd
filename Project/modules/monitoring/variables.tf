variable "cluster_name" {
  description = "Назва EKS кластера"
  type        = string
}

variable "kubernetes_host" {
  description = "Endpoint Kubernetes API"
  type        = string
}

variable "kubernetes_token" {
  description = "Токен для доступу до Kubernetes API"
  type        = string
  sensitive   = true
}

variable "kubernetes_cluster_ca_cert" {
  description = "CA сертифікат Kubernetes кластера"
  type        = string
}

variable "namespace" {
  description = "Namespace для Prometheus + Grafana"
  type        = string
  default     = "monitoring"
}

variable "release_name" {
  description = "Назва Helm релізу kube-prometheus-stack"
  type        = string
  default     = "kube-prometheus-stack"
}

variable "chart_version" {
  description = "Версія Helm chart kube-prometheus-stack"
  type        = string
  default     = "68.4.0"
}

variable "grafana_admin_user" {
  description = "Логін Grafana admin"
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Пароль Grafana admin. Передавайте через TF_VAR_grafana_admin_password."
  type        = string
  sensitive   = true
}

variable "prometheus_retention" {
  description = "Термін зберігання метрик Prometheus"
  type        = string
  default     = "15d"
}

variable "prometheus_storage_size" {
  description = "Розмір PVC для Prometheus (EBS)"
  type        = string
  default     = "20Gi"
}

variable "grafana_storage_size" {
  description = "Розмір PVC для Grafana (EBS)"
  type        = string
  default     = "5Gi"
}

variable "storage_class_name" {
  description = "StorageClass для PVC (gp2 - стандартний у EKS з EBS CSI driver)"
  type        = string
  default     = "gp2"
}

variable "alertmanager_enabled" {
  description = "Вмикати AlertManager"
  type        = bool
  default     = false
}
