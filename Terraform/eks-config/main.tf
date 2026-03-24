resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"

  create_namespace = true
  values = [file("${path.module}/values/ingress_values.yaml")]
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"

  create_namespace = true
  values = [file("${path.module}/values/prometheus_values.yaml")]

  depends_on = [helm_release.ingress_nginx]
}

# Fluent Bit for CloudWatch Logging
resource "helm_release" "fluent_bit" {
  name             = "aws-for-fluent-bit"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-for-fluent-bit"
  version          = "0.2.0"
  namespace        = "amazon-cloudwatch"
  create_namespace = true

  values = [
    templatefile("${path.module}/values/fluent-bit-values.yaml", {
      log_group_name = var.cloudwatch_log_group
      aws_region     = var.aws_region
    })
  ]

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.7.0"
  namespace        = "argocd"
  create_namespace = true

  values = [file("${path.module}/values/argocd-values.yaml")]

  depends_on = [helm_release.kube_prometheus_stack]
}

# Repo credential secret — ArgoCD uses this to clone the private GitHub repo.
# The label argocd.argoproj.io/secret-type=repository is how ArgoCD discovers it.
resource "kubernetes_secret" "argocd_repo_creds" {
  metadata {
    name      = "my-app-repo"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type     = "git"
    url      = "https://github.com/shirasss/EKS-With-ArgoCD"
    username = "git"
    password = var.github_token
  }

  depends_on = [helm_release.argocd]
}

# Register the ArgoCD Application — tells ArgoCD which repo/path to watch.
# Uses kubectl_manifest (gavinbunney/kubectl) instead of kubernetes_manifest
# because kubernetes_manifest requires cluster connectivity at plan time.
resource "kubectl_manifest" "argocd_app" {
  yaml_body = file("${path.module}/argocd-app.yaml")

  depends_on = [kubernetes_secret.argocd_repo_creds]
}