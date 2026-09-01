output "artifact_registry_repository" {
  value = google_artifact_registry_repository.bank.name
}

output "workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}

output "app_ci_service_account" {
  value = google_service_account.app_ci.email
}
