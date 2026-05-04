# ─────────────────────────────────────────────
# Локальні обчислення
# ─────────────────────────────────────────────

locals {
  # Порт за замовчуванням залежно від движка
  db_port = var.port != null ? var.port : (
    contains(["postgres", "aurora-postgresql"], var.engine) ? 5432 : 3306
  )

  # Чи використовується PostgreSQL-сумісний движок
  is_postgres = contains(["postgres", "aurora-postgresql"], var.engine)
  is_mysql    = contains(["mysql", "aurora-mysql"], var.engine)

  # Автоматичне визначення сімейства parameter group
  # Логіка: беремо перші два сегменти версії (15.8 → 15, 8.0.40 → 8.0)
  _engine_major = local.is_postgres ? split(".", var.engine_version)[0] : join(".", slice(split(".", var.engine_version), 0, 2))
  pg_family = var.parameter_group_family != null ? var.parameter_group_family : (
    var.engine == "postgres" ? "postgres${local._engine_major}" :
    var.engine == "mysql" ? "mysql${local._engine_major}" :
    var.engine == "aurora-postgresql" ? "aurora-postgresql${local._engine_major}" :
    "aurora-mysql${local._engine_major}"
  )

  # Параметри для PostgreSQL
  pg_parameters = [
    { name = "max_connections", value = "200",   apply_method = "pending-reboot" },
    { name = "log_statement",   value = "ddl",   apply_method = "immediate" },
    { name = "work_mem",        value = "65536", apply_method = "immediate" },
  ]

  # Параметри для MySQL / Aurora MySQL
  mysql_parameters = [
    { name = "max_connections",  value = "300", apply_method = "pending-reboot" },
    { name = "general_log",      value = "1",   apply_method = "immediate" },
    { name = "slow_query_log",   value = "1",   apply_method = "immediate" },
    { name = "long_query_time",  value = "2",   apply_method = "immediate" },
  ]

  db_parameters = local.is_postgres ? local.pg_parameters : local.mysql_parameters

  common_tags = merge(
    var.tags,
    {
      Module     = "rds"
      Identifier = var.identifier
      ManagedBy  = "Terraform"
    }
  )
}

# ─────────────────────────────────────────────
# DB Subnet Group
# ─────────────────────────────────────────────

resource "aws_db_subnet_group" "this" {
  name        = "${var.identifier}-subnet-group"
  description = "Subnet group for ${var.identifier} RDS/Aurora"
  subnet_ids  = var.subnet_ids

  tags = merge(local.common_tags, { Name = "${var.identifier}-subnet-group" })
}

# ─────────────────────────────────────────────
# Security Group
# ─────────────────────────────────────────────

resource "aws_security_group" "this" {
  name        = "${var.identifier}-rds-sg"
  description = "Security group for ${var.identifier} RDS/Aurora - port ${local.db_port}"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, { Name = "${var.identifier}-rds-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

# Ingress: дозволені CIDR-блоки
resource "aws_vpc_security_group_ingress_rule" "cidr" {
  for_each = toset(var.allowed_cidr_blocks)

  security_group_id = aws_security_group.this.id
  description       = "Allow DB access from ${each.value}"
  from_port         = local.db_port
  to_port           = local.db_port
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value

  tags = local.common_tags
}

# Ingress: дозволені Security Groups (наприклад EKS nodes)
resource "aws_vpc_security_group_ingress_rule" "sgs" {
  for_each = toset(var.allowed_security_group_ids)

  security_group_id            = aws_security_group.this.id
  description                  = "Allow DB access from SG ${each.value}"
  from_port                    = local.db_port
  to_port                      = local.db_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = each.value

  tags = local.common_tags
}

# Egress: дозволяємо весь вихідний трафік
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = local.common_tags
}

# ─────────────────────────────────────────────
# Parameter Group - звичайна RDS (aws_db_parameter_group)
# ─────────────────────────────────────────────

resource "aws_db_parameter_group" "this" {
  count = var.use_aurora ? 0 : 1

  name        = "${var.identifier}-pg"
  family      = local.pg_family
  description = "Parameter group for ${var.identifier} (${var.engine} ${var.engine_version})"

  dynamic "parameter" {
    for_each = local.db_parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  tags = merge(local.common_tags, { Name = "${var.identifier}-pg" })

  lifecycle {
    create_before_destroy = true
  }
}

# ─────────────────────────────────────────────
# Parameter Group - Aurora (aws_rds_cluster_parameter_group + aws_db_parameter_group)
# ─────────────────────────────────────────────

# Cluster-level параметри (застосовуються до всього кластера)
resource "aws_rds_cluster_parameter_group" "this" {
  count = var.use_aurora ? 1 : 0

  name        = "${var.identifier}-cluster-pg"
  family      = local.pg_family
  description = "Cluster parameter group for ${var.identifier} Aurora (${var.engine} ${var.engine_version})"

  dynamic "parameter" {
    for_each = local.db_parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  tags = merge(local.common_tags, { Name = "${var.identifier}-cluster-pg" })

  lifecycle {
    create_before_destroy = true
  }
}

# Instance-level параметри (Aurora instance parameter group - зазвичай залишаємо default)
resource "aws_db_parameter_group" "aurora_instance" {
  count = var.use_aurora ? 1 : 0

  name        = "${var.identifier}-instance-pg"
  family      = local.pg_family
  description = "Instance parameter group for ${var.identifier} Aurora instances"

  tags = merge(local.common_tags, { Name = "${var.identifier}-instance-pg" })

  lifecycle {
    create_before_destroy = true
  }
}
