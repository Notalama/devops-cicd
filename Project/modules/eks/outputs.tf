output "cluster_name" {
  description = "Назва EKS кластера"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "API endpoint EKS кластера"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 CA дані для підключення до кластера"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}
