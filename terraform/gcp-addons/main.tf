resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "2.10.0"
  namespace        = "external-secrets"
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [yamlencode({
    installCRDs = true
  })]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.6.0"
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 900

  values = [yamlencode({
    configs = {
      params = {
        "server.insecure" = true
      }
    }
    server = {
      service = {
        type = "ClusterIP"
      }
    }
    dex = {
      enabled = false
    }
    notifications = {
      enabled = false
    }
  })]

  depends_on = [helm_release.external_secrets]
}

locals {
  dr_control_subject = "github-bank-dr-control@${var.project_id}.iam.gserviceaccount.com"
}

resource "kubernetes_role_v1" "dr_argocd" {
  metadata {
    name      = "github-dr-control"
    namespace = "argocd"
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "statefulsets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["argoproj.io"]
    resources  = ["applications"]
    verbs      = ["get", "list", "watch", "create", "update", "patch"]
  }

  depends_on = [helm_release.argocd]
}

resource "kubernetes_role_binding_v1" "dr_argocd" {
  metadata {
    name      = "github-dr-control"
    namespace = "argocd"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.dr_argocd.metadata[0].name
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name      = local.dr_control_subject
  }
}

resource "kubernetes_role_v1" "dr_external_secrets" {
  metadata {
    name      = "github-dr-read"
    namespace = "external-secrets"
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["get", "list", "watch"]
  }

  depends_on = [helm_release.external_secrets]
}

resource "kubernetes_role_binding_v1" "dr_external_secrets" {
  metadata {
    name      = "github-dr-read"
    namespace = "external-secrets"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.dr_external_secrets.metadata[0].name
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name      = local.dr_control_subject
  }
}

resource "kubernetes_role_v1" "dr_workloads" {
  metadata {
    name      = "github-dr-read"
    namespace = "bank-dr"
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["external-secrets.io"]
    resources  = ["externalsecrets", "secretstores"]
    verbs      = ["get", "list", "watch"]
  }

  depends_on = [helm_release.argocd]
}

resource "kubernetes_role_binding_v1" "dr_workloads" {
  metadata {
    name      = "github-dr-read"
    namespace = "bank-dr"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.dr_workloads.metadata[0].name
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name      = local.dr_control_subject
  }
}
