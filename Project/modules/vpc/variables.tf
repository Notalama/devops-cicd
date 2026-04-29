variable "vpc_cidr_block" {
  type        = string
  description = "CIDR блок для VPC"
}

variable "public_subnets" {
  type        = list(string)
  description = "Список CIDR блоків для публічних підмереж"
}

variable "private_subnets" {
  type        = list(string)
  description = "Список CIDR блоків для приватних підмереж"
}

variable "availability_zones" {
  type        = list(string)
  description = "Список AZ (зон доступності)"
}

variable "vpc_name" {
  type        = string
  description = "Назва VPC"
}
