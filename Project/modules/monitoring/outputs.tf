output "namespace" {
  description = "Namespace, де встановлено Prometheus + Grafana"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "release_name" {
  description = "Назва Helm релізу kube-prometheus-stack"
  value       = helm_release.kube_prometheus_stack.name
}

output "grafana_service_name" {
  description = "Назва Kubernetes Service для Grafana (для port-forward)"
  value       = "${helm_release.kube_prometheus_stack.name}-grafana"
}

output "prometheus_service_name" {
  description = "Назва Kubernetes Service для Prometheus (для port-forward)"
  value       = "${helm_release.kube_prometheus_stack.name}-prometheus"
}

output "alertmanager_service_name" {
  description = "Назва Kubernetes Service для AlertManager"
  value       = "${helm_release.kube_prometheus_stack.name}-alertmanager"
}
