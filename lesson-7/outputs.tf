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
