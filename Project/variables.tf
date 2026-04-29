variable "db_master_password" {
  type        = string
  sensitive   = true
  description = <<-EOT
    Пароль master-користувача для RDS / Aurora.
    Передавайте через змінну середовища TF_VAR_db_master_password або AWS Secrets Manager,
    ніколи не записуйте значення безпосередньо у код.

    Приклад передачі:
      export TF_VAR_db_master_password="$(aws secretsmanager get-secret-value \
        --secret-id my-app/db/password --query SecretString --output text | jq -r .password)"
  EOT
}
