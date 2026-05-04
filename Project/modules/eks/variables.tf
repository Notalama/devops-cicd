variable "cluster_name" {
  description = "Назва EKS кластера"
  type        = string
  default     = "django-eks-cluster"
}

variable "vpc_id" {
  description = "ID існуючої VPC"
  type        = string
}

variable "subnet_ids" {
  description = "Список приватних підмереж для вузлів кластера"
  type        = list(string)
}
