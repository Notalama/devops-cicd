variable "ecr_name" {
  description = "Назва ECR репозиторію"
  type        = string
}

variable "scan_on_push" {
  description = "Чи сканувати образи на вразливості при завантаженні"
  type        = bool
  default     = true
}
