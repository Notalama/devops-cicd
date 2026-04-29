# ─────────────────────────────────────────────
# Security Group
# ─────────────────────────────────────────────

output "security_group_id" {
  description = "ID security group, прив'язаного до БД."
  value       = aws_security_group.this.id
}

output "security_group_arn" {
  description = "ARN security group, прив'язаного до БД."
  value       = aws_security_group.this.arn
}

# ─────────────────────────────────────────────
# Subnet Group
# ─────────────────────────────────────────────

output "db_subnet_group_name" {
  description = "Назва DB Subnet Group."
  value       = aws_db_subnet_group.this.name
}

output "db_subnet_group_arn" {
  description = "ARN DB Subnet Group."
  value       = aws_db_subnet_group.this.arn
}

# ─────────────────────────────────────────────
# Parameter Groups
# ─────────────────────────────────────────────

output "parameter_group_name" {
  description = "Назва Parameter Group (для RDS — aws_db_parameter_group; для Aurora — aws_rds_cluster_parameter_group)."
  value = var.use_aurora ? aws_rds_cluster_parameter_group.this[0].name : aws_db_parameter_group.this[0].name
}

# ─────────────────────────────────────────────
# Уніфікований endpoint (зручний для аплікацій)
# ─────────────────────────────────────────────

output "db_endpoint" {
  description = "Основний endpoint для підключення (writer endpoint для Aurora, address для RDS)."
  value       = var.use_aurora ? aws_rds_cluster.this[0].endpoint : aws_db_instance.this[0].address
}

output "db_reader_endpoint" {
  description = "Reader endpoint (тільки Aurora). Для RDS повертає той самий endpoint."
  value       = var.use_aurora ? aws_rds_cluster.this[0].reader_endpoint : aws_db_instance.this[0].address
}

output "db_port" {
  description = "Порт для підключення до БД."
  value       = local.db_port
}

output "db_name" {
  description = "Назва початкової бази даних."
  value       = var.database_name
}

output "master_username" {
  description = "Ім'я master-користувача."
  value       = var.master_username
}

# ─────────────────────────────────────────────
# Специфічні виводи для RDS Instance
# ─────────────────────────────────────────────

output "rds_instance_id" {
  description = "(Тільки RDS) Ідентифікатор aws_db_instance."
  value       = var.use_aurora ? null : aws_db_instance.this[0].id
}

output "rds_instance_arn" {
  description = "(Тільки RDS) ARN aws_db_instance."
  value       = var.use_aurora ? null : aws_db_instance.this[0].arn
}

output "rds_instance_resource_id" {
  description = "(Тільки RDS) Resource ID (корисний для IAM auth)."
  value       = var.use_aurora ? null : aws_db_instance.this[0].resource_id
}

# ─────────────────────────────────────────────
# Специфічні виводи для Aurora Cluster
# ─────────────────────────────────────────────

output "aurora_cluster_id" {
  description = "(Тільки Aurora) Ідентифікатор кластера."
  value       = var.use_aurora ? aws_rds_cluster.this[0].id : null
}

output "aurora_cluster_arn" {
  description = "(Тільки Aurora) ARN кластера."
  value       = var.use_aurora ? aws_rds_cluster.this[0].arn : null
}

output "aurora_cluster_resource_id" {
  description = "(Тільки Aurora) Resource ID кластера (корисний для IAM auth)."
  value       = var.use_aurora ? aws_rds_cluster.this[0].cluster_resource_id : null
}

output "aurora_instance_ids" {
  description = "(Тільки Aurora) Список ID усіх cluster instances."
  value       = var.use_aurora ? aws_rds_cluster_instance.this[*].id : []
}
