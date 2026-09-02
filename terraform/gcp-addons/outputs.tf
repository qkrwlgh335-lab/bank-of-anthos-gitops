output "argocd_namespace" {
  value = helm_release.argocd.namespace
}

output "external_secrets_namespace" {
  value = helm_release.external_secrets.namespace
}
