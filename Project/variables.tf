variable "db_master_password" {
  type        = string
  sensitive   = true
  description = <<-EOT
    Пароль master-користувача для RDS / Aurora.
    Передавайте через змінну середовища TF_VAR_db_master_password або AWS Secrets Manager,
    ніколи не записуйте значення безпосередньо у код.

    Приклад:
      export TF_VAR_db_master_password="YourStr0ngPassword!"
  EOT
}

variable "grafana_admin_password" {
  type        = string
  sensitive   = true
  description = <<-EOT
    Пароль admin-користувача Grafana.
    Передавайте через змінну середовища TF_VAR_grafana_admin_password.

    Приклад:
      export TF_VAR_grafana_admin_password="GrafanaPass123!"
  EOT
}
