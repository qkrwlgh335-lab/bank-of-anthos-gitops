output "argocd_namespace" {
  value = helm_release.argocd.namespace
}

output "installed_releases" {
  value = [
    helm_release.aws_load_balancer_controller.name,
    helm_release.external_secrets.name,
    helm_release.argocd.name,
  ]
}
