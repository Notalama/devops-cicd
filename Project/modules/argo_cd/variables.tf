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
  description = "Namespace для Argo CD"
  type        = string
  default     = "argocd"
}

variable "release_name" {
  description = "Назва Helm релізу Argo CD"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "Версія Helm chart Argo CD"
  type        = string
  default     = "7.7.16"
}

variable "gitops_repo_url" {
  description = "Git репозиторій, за яким стежить Argo CD"
  type        = string
}

variable "app_target_path" {
  description = "Шлях до Helm chart у GitOps репозиторії"
  type        = string
}

variable "app_target_branch" {
  description = "Цільова гілка GitOps репозиторію"
  type        = string
  default     = "main"
}
