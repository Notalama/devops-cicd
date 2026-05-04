resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "argocd" {
  name             = var.release_name
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_version
  create_namespace = false
  timeout          = 300

  values = [
    file("${path.module}/values.yaml")
  ]

  depends_on = [kubernetes_namespace.argocd]
}

resource "helm_release" "argocd_apps" {
  name             = "argocd-apps"
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  chart            = "${path.module}/charts"
  create_namespace = false
  timeout          = 600

  values = [
    templatefile("${path.module}/charts/values.yaml", {
      gitops_repo_url   = var.gitops_repo_url
      app_target_path   = var.app_target_path
      app_target_branch = var.app_target_branch
    })
  ]

  depends_on = [helm_release.argocd]
}
