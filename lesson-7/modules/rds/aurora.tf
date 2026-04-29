# ─────────────────────────────────────────────
# Aurora Cluster (use_aurora = true)
# ─────────────────────────────────────────────

resource "aws_rds_cluster" "this" {
  count = var.use_aurora ? 1 : 0

  cluster_identifier = var.identifier
  engine             = var.engine
  engine_version     = var.engine_version

  # БД та облікові дані
  database_name   = var.database_name
  master_username = var.master_username
  master_password = var.master_password
  port            = local.db_port

  # Мережа
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  # Parameter Groups
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this[0].name

  # Шифрування
  storage_encrypted = var.storage_encrypted
  kms_key_id        = var.kms_key_id

  # Backup
  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window
  apply_immediately            = var.apply_immediately

  # Snapshot та захист
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.final_snapshot_identifier_prefix}-${var.identifier}"

  # Логи CloudWatch
  enabled_cloudwatch_logs_exports = local.is_postgres ? ["postgresql"] : ["error", "general", "slowquery"]

  tags = merge(local.common_tags, { Name = var.identifier })
}

# ─────────────────────────────────────────────
# Aurora Cluster Instances
# ─────────────────────────────────────────────

resource "aws_rds_cluster_instance" "this" {
  count = var.use_aurora ? var.replica_count : 0

  identifier         = "${var.identifier}-${count.index}"
  cluster_identifier = aws_rds_cluster.this[0].id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.this[0].engine
  engine_version     = aws_rds_cluster.this[0].engine_version

  # Parameter Group на рівні instance
  db_parameter_group_name = aws_db_parameter_group.aurora_instance[0].name

  # Мережа
  db_subnet_group_name = aws_db_subnet_group.this.name
  publicly_accessible  = false

  # Maintenance
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  preferred_maintenance_window = var.preferred_maintenance_window
  apply_immediately            = var.apply_immediately

  # Enhanced Monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.aurora_enhanced_monitoring[0].arn

  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  tags = merge(local.common_tags, {
    Name = "${var.identifier}-${count.index}"
    Role = count.index == 0 ? "writer" : "reader"
  })
}

# ─────────────────────────────────────────────
# IAM Role для Enhanced Monitoring (Aurora)
# ─────────────────────────────────────────────

resource "aws_iam_role" "aurora_enhanced_monitoring" {
  count = var.use_aurora ? 1 : 0

  name = "${var.identifier}-aurora-monitoring-role"

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

resource "aws_iam_role_policy_attachment" "aurora_enhanced_monitoring" {
  count = var.use_aurora ? 1 : 0

  role       = aws_iam_role.aurora_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
