output "namespace" {
  description = "Namespace, де встановлено Jenkins"
  value       = kubernetes_namespace.jenkins.metadata[0].name
}

output "release_name" {
  description = "Назва Helm релізу Jenkins"
  value       = helm_release.jenkins.name
}
