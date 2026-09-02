# Phase 1 bootstrapped these unique-name resources before this remote state was
# established. Configuration-driven imports are repeatable: once an object is
# in state, later plans do not attempt another import. New environments leave
# adopt_existing_resources=false and create the objects normally.

import {
  for_each = var.adopt_existing_resources ? toset(["artifact_repository"]) : toset([])

  to = google_artifact_registry_repository.bank
  id = "projects/${var.project_id}/locations/${var.region}/repositories/${var.artifact_repository}"
}

import {
  for_each = var.adopt_existing_resources ? toset(["app_ci_service_account"]) : toset([])

  to = google_service_account.app_ci
  id = "projects/${var.project_id}/serviceAccounts/${var.app_ci_service_account_id}@${var.project_id}.iam.gserviceaccount.com"
}

import {
  for_each = var.adopt_existing_resources ? toset(["workload_identity_pool"]) : toset([])

  to = google_iam_workload_identity_pool.github
  id = "projects/${var.project_id}/locations/global/workloadIdentityPools/${var.workload_identity_pool_id}"
}

import {
  for_each = var.adopt_existing_resources ? toset(["workload_identity_provider"]) : toset([])

  to = google_iam_workload_identity_pool_provider.github
  id = "projects/${var.project_id}/locations/global/workloadIdentityPools/${var.workload_identity_pool_id}/providers/${var.workload_identity_provider_id}"
}
