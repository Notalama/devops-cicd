# ─────────────────────────────────────────────
# Звичайна RDS Instance (use_aurora = false)
# ─────────────────────────────────────────────

resource "aws_db_instance" "this" {
  count = var.use_aurora ? 0 : 1

  # Ідентифікатор та движок
  identifier     = var.identifier
  engine         = var.engine
  engine_version = var.engine_version

  # Клас та сховище
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage > 0 ? var.max_allocated_storage : null
  storage_type          = var.storage_type
  iops                  = var.iops

  # БД та облікові дані
  db_name  = var.database_name
  username = var.master_username
  password = var.master_password
  port     = local.db_port

  # Мережа
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  multi_az               = var.multi_az
  publicly_accessible    = false

  # Parameter Group
  parameter_group_name = aws_db_parameter_group.this[0].name

  # Шифрування
  storage_encrypted = var.storage_encrypted
  kms_key_id        = var.kms_key_id

  # Backup
  backup_retention_period   = var.backup_retention_period
  backup_window             = var.preferred_backup_window
  maintenance_window        = var.preferred_maintenance_window
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately

  # Snapshot та захист від видалення
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.final_snapshot_identifier_prefix}-${var.identifier}"

  # Моніторинг
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.rds_enhanced_monitoring[0].arn

  # Логи: для PostgreSQL відправляємо postgresql та upgrade, для MySQL - error, general, slowquery
  enabled_cloudwatch_logs_exports = local.is_postgres ? ["postgresql", "upgrade"] : ["error", "general", "slowquery"]

  tags = merge(local.common_tags, { Name = var.identifier })
}

# ─────────────────────────────────────────────
# IAM Role для Enhanced Monitoring (RDS)
# ─────────────────────────────────────────────

resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = var.use_aurora ? 0 : 1

  name = "${var.identifier}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count = var.use_aurora ? 0 : 1

  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
