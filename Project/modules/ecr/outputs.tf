output "repository_url" {
  description = "URL репозиторію ECR"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ARN репозиторію ECR"
  value       = aws_ecr_repository.this.arn
}
