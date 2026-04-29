output "namespace" {
  description = "Namespace, де встановлено Argo CD"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "release_name" {
  description = "Назва Helm релізу Argo CD"
  value       = helm_release.argocd.name
}
