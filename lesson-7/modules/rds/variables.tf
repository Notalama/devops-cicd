# ─────────────────────────────────────────────
# Загальні налаштування
# ─────────────────────────────────────────────

variable "identifier" {
  type        = string
  description = "Унікальний ідентифікатор / префікс імені для всіх ресурсів модуля (DB, SG, Subnet Group тощо)."
}

variable "use_aurora" {
  type        = bool
  default     = false
  description = "true → створити Aurora Cluster + writer instance. false → створити звичайну RDS instance."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Мета-теги, які будуть застосовані до всіх ресурсів модуля."
}

# ─────────────────────────────────────────────
# Engine
# ─────────────────────────────────────────────

variable "engine" {
  type        = string
  default     = "postgres"
  description = <<-EOT
    Движок бази даних.
    Для звичайної RDS: "postgres" або "mysql".
    Для Aurora:        "aurora-postgresql" або "aurora-mysql".
  EOT

  validation {
    condition     = contains(["postgres", "mysql", "aurora-postgresql", "aurora-mysql"], var.engine)
    error_message = "Допустимі значення: postgres, mysql, aurora-postgresql, aurora-mysql."
  }
}

variable "engine_version" {
  type        = string
  default     = "15.8"
  description = "Версія движка. Приклади: \"15.8\" (PostgreSQL), \"8.0.40\" (MySQL), \"15.4\" (Aurora PostgreSQL), \"8.0.mysql_aurora.3.06.0\" (Aurora MySQL)."
}

variable "parameter_group_family" {
  type        = string
  default     = null
  description = <<-EOT
    Сімейство parameter group. Якщо null — обчислюється автоматично з engine та engine_version.
    Приклади: postgres15, postgres14, mysql8.0, aurora-postgresql15, aurora-mysql8.0.
  EOT
}

# ─────────────────────────────────────────────
# Клас інстансу
# ─────────────────────────────────────────────

variable "instance_class" {
  type        = string
  default     = "db.t3.medium"
  description = "Клас EC2-інстансу для БД. Приклади: db.t3.medium, db.r6g.large, db.r6g.2xlarge."
}

# ─────────────────────────────────────────────
# Мережа
# ─────────────────────────────────────────────

variable "vpc_id" {
  type        = string
  description = "ID VPC, в якій буде створено базу даних."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Список ID підмереж для DB Subnet Group (мінімум 2, в різних AZ)."

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Потрібно передати щонайменше 2 підмережі в різних AZ."
  }
}

variable "port" {
  type        = number
  default     = null
  description = "Порт БД. Якщо null — використовується 5432 для PostgreSQL та 3306 для MySQL."
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  default     = []
  description = "CIDR-блоки, яким дозволено підключатись до БД."
}

variable "allowed_security_group_ids" {
  type        = list(string)
  default     = []
  description = "ID security group (наприклад EKS node SG), яким дозволено підключатись до БД."
}

# ─────────────────────────────────────────────
# Облікові дані
# ─────────────────────────────────────────────

variable "database_name" {
  type        = string
  description = "Назва початкової бази даних, яку буде створено при запуску."
}

variable "master_username" {
  type        = string
  description = "Ім'я головного користувача (admin / postgres тощо)."
}

variable "master_password" {
  type        = string
  sensitive   = true
  description = "Пароль головного користувача. Зберігайте в AWS Secrets Manager або Vault — не в коді."
}

# ─────────────────────────────────────────────
# Параметри, що застосовуються лише до звичайної RDS
# ─────────────────────────────────────────────

variable "allocated_storage" {
  type        = number
  default     = 20
  description = "(Тільки RDS) Початковий розмір сховища в ГБ."
}

variable "max_allocated_storage" {
  type        = number
  default     = 100
  description = "(Тільки RDS) Максимальний розмір autoscaling-сховища в ГБ. 0 — вимкнути autoscaling."
}

variable "storage_type" {
  type        = string
  default     = "gp3"
  description = "(Тільки RDS) Тип EBS: gp2, gp3, io1, io2."
}

variable "iops" {
  type        = number
  default     = null
  description = "(Тільки RDS) Кількість IOPS для io1/io2/gp3. Для gp3 мінімум 3000."
}

variable "multi_az" {
  type        = bool
  default     = false
  description = "(Тільки RDS) Ввімкнути Multi-AZ для high availability."
}

# ─────────────────────────────────────────────
# Параметри, що застосовуються лише до Aurora
# ─────────────────────────────────────────────

variable "replica_count" {
  type        = number
  default     = 1
  description = "(Тільки Aurora) Кількість instance у кластері (включно з writer). Мінімум 1."

  validation {
    condition     = var.replica_count >= 1
    error_message = "replica_count має бути >= 1."
  }
}

# ─────────────────────────────────────────────
# Backup та Maintenance
# ─────────────────────────────────────────────

variable "backup_retention_period" {
  type        = number
  default     = 7
  description = "Кількість днів зберігання автоматичних бекапів (0 — вимкнути)."
}

variable "preferred_backup_window" {
  type        = string
  default     = "03:00-04:00"
  description = "Вікно для автоматичних бекапів у форматі hh24:mi-hh24:mi (UTC)."
}

variable "preferred_maintenance_window" {
  type        = string
  default     = "Mon:04:00-Mon:05:00"
  description = "Вікно для технічного обслуговування у форматі ddd:hh24:mi-ddd:hh24:mi (UTC)."
}

variable "auto_minor_version_upgrade" {
  type        = bool
  default     = true
  description = "Автоматично застосовувати мінорні оновлення движка під час вікна обслуговування."
}

variable "apply_immediately" {
  type        = bool
  default     = false
  description = "Застосовувати зміни негайно (true) або під час вікна обслуговування (false)."
}

# ─────────────────────────────────────────────
# Шифрування
# ─────────────────────────────────────────────

variable "storage_encrypted" {
  type        = bool
  default     = true
  description = "Шифрувати сховище БД за допомогою KMS."
}

variable "kms_key_id" {
  type        = string
  default     = null
  description = "ARN власного KMS-ключа для шифрування. Якщо null — використовується aws/rds managed key."
}

# ─────────────────────────────────────────────
# Snapshot та Deletion Protection
# ─────────────────────────────────────────────

variable "deletion_protection" {
  type        = bool
  default     = true
  description = "Захист від випадкового видалення. Рекомендується true для production."
}

variable "skip_final_snapshot" {
  type        = bool
  default     = false
  description = "Пропустити фінальний snapshot при видаленні. false (рекомендовано для prod) — знімок буде зроблено."
}

variable "final_snapshot_identifier_prefix" {
  type        = string
  default     = "final"
  description = "Префікс для імені фінального snapshot."
}
