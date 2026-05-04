# ─────────────────────────────────────────────
# Namespace
# ─────────────────────────────────────────────

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "monitoring"                   = "true"
    }
  }
}

# ─────────────────────────────────────────────
# kube-prometheus-stack
# Includes: Prometheus, Grafana, AlertManager,
#           Node Exporter, kube-state-metrics
# ─────────────────────────────────────────────

resource "helm_release" "kube_prometheus_stack" {
  name             = var.release_name
  namespace        = kubernetes_namespace.monitoring.metadata[0].name
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.chart_version
  create_namespace = false
  timeout          = 600

  values = [
    templatefile("${path.module}/values.yaml", {
      grafana_admin_user      = var.grafana_admin_user
      grafana_admin_password  = var.grafana_admin_password
      prometheus_retention    = var.prometheus_retention
      prometheus_storage_size = var.prometheus_storage_size
      grafana_storage_size    = var.grafana_storage_size
      storage_class_name      = var.storage_class_name
      alertmanager_enabled    = var.alertmanager_enabled
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

# ─────────────────────────────────────────────
# ServiceMonitor для Django app
# Scrapes /metrics якщо додаток їх публікує
# ─────────────────────────────────────────────

resource "kubernetes_manifest" "django_service_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "django-app"
      namespace = var.namespace
      labels = {
        release = var.release_name
      }
    }
    spec = {
      namespaceSelector = {
        matchNames = ["django-app"]
      }
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "django-app"
        }
      }
      endpoints = [
        {
          port     = "http"
          path     = "/metrics"
          interval = "30s"
        }
      ]
    }
  }

  depends_on = [helm_release.kube_prometheus_stack]
}
