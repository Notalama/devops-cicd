resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "jenkins" {
  name             = var.release_name
  namespace        = kubernetes_namespace.jenkins.metadata[0].name
  repository       = "https://charts.jenkins.io"
  chart            = "jenkins"
  version          = var.chart_version
  create_namespace = false
  timeout          = 900

  values = [
    templatefile("${path.module}/values.yaml", {
      admin_user       = var.admin_user
      admin_password   = var.admin_password
      ecr_repository   = var.ecr_repository_url
      aws_region       = var.aws_region
      kubernetes_cloud = var.cluster_name
    })
  ]

  depends_on = [kubernetes_namespace.jenkins]
}
