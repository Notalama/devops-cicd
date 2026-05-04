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
  description = "Namespace для Jenkins"
  type        = string
  default     = "jenkins"
}

variable "release_name" {
  description = "Назва Helm релізу Jenkins"
  type        = string
  default     = "jenkins"
}

variable "chart_version" {
  description = "Версія Jenkins Helm chart"
  type        = string
  default     = "5.9.18"
}

variable "admin_user" {
  description = "Логін Jenkins admin"
  type        = string
  default     = "admin"
}

variable "admin_password" {
  description = "Пароль Jenkins admin"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!"
}

variable "ecr_repository_url" {
  description = "URL ECR репозиторію для білдів"
  type        = string
}

variable "aws_region" {
  description = "AWS регіон для ECR"
  type        = string
  default     = "eu-north-1"
}
