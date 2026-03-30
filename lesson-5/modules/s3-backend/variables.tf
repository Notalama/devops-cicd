variable "bucket_name" {
  description = "Назва S3 бакета для зберігання terraform state"
  type        = string
}

variable "table_name" {
  description = "Назва DynamoDB таблиці для блокування стейту"
  type        = string
  default     = "terraform-locks"
}
