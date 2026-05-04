output "s3_bucket_name" {
  value = module.s3_backend.s3_bucket_arn
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "jenkins_namespace" {
  value = module.jenkins.namespace
}

output "jenkins_release" {
  value = module.jenkins.release_name
}

output "argo_cd_namespace" {
  value = module.argo_cd.namespace
}

output "argo_cd_release" {
  value = module.argo_cd.release_name
}

# ─── RDS Postgres ────────────────────────────────────────────────────────────

output "rds_postgres_endpoint" {
  description = "Endpoint звичайного PostgreSQL RDS інстансу"
  value       = module.rds_postgres.db_endpoint
}

output "rds_postgres_port" {
  description = "Порт PostgreSQL RDS"
  value       = module.rds_postgres.db_port
}

output "rds_postgres_security_group_id" {
  description = "Security Group ID для PostgreSQL RDS"
  value       = module.rds_postgres.security_group_id
}

# ─── Aurora PostgreSQL ───────────────────────────────────────────────────────

output "aurora_writer_endpoint" {
  description = "Writer endpoint Aurora кластера"
  value       = module.rds_aurora.db_endpoint
}

output "aurora_reader_endpoint" {
  description = "Reader endpoint Aurora кластера"
  value       = module.rds_aurora.db_reader_endpoint
}

output "aurora_cluster_id" {
  description = "ID Aurora кластера"
  value       = module.rds_aurora.aurora_cluster_id
}

output "aurora_security_group_id" {
  description = "Security Group ID для Aurora"
  value       = module.rds_aurora.security_group_id
}

# ─── Monitoring ──────────────────────────────────────────────────────────────

output "monitoring_namespace" {
  description = "Namespace для Prometheus + Grafana"
  value       = module.monitoring.namespace
}

output "grafana_service_name" {
  description = "Service name Grafana - для port-forward"
  value       = module.monitoring.grafana_service_name
}

output "prometheus_service_name" {
  description = "Service name Prometheus - для port-forward"
  value       = module.monitoring.prometheus_service_name
}

