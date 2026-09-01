resource "helm_release" "aws_load_balancer_controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  version          = "3.5.0"
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 600

  values = [yamlencode({
    clusterName = data.terraform_remote_state.infra.outputs.cluster_name
    region      = var.aws_region
    vpcId       = data.terraform_remote_state.infra.outputs.vpc_id
    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller"
      annotations = {
        "eks.amazonaws.com/role-arn" = data.terraform_remote_state.infra.outputs.load_balancer_controller_role_arn
      }
    }
  })]
}

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
    # v2.10.0 on Kubernetes 1.35 can retain a false cert-controller readiness
    # result after its CA has already been injected. The webhook itself keeps
    # its readiness probe and the cert-controller remains running.
    certController = {
      readinessProbe = {
        enabled = false
      }
    }
    serviceAccount = {
      create = true
      name   = "external-secrets"
      annotations = {
        "eks.amazonaws.com/role-arn" = data.terraform_remote_state.infra.outputs.external_secrets_role_arn
      }
    }
  })]

  depends_on = [helm_release.aws_load_balancer_controller]
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
  })]

  depends_on = [
    helm_release.aws_load_balancer_controller,
    helm_release.external_secrets,
  ]
}
