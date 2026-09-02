locals {
  app_repo_full      = "${var.github_owner}/${var.app_repository}"
  platform_repo_full = "${var.github_owner}/${var.platform_repository}"
  required_apis = toset([
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ])
}

resource "google_project_service" "required" {
  for_each = local.required_apis

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "bank" {
  location      = var.region
  repository_id = var.artifact_repository
  description   = "DR copy of immutable Bank of Anthos service images"
  format        = "DOCKER"

  cleanup_policy_dry_run = false
  cleanup_policies {
    id     = "keep-latest-ten"
    action = "KEEP"
    most_recent_versions {
      keep_count = 10
    }
  }

  depends_on = [google_project_service.required]
}

resource "google_service_account" "app_ci" {
  account_id   = var.app_ci_service_account_id
  display_name = "GitHub Bank App CI (WIF only)"
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = var.workload_identity_pool_id
  display_name              = "GitHub Actions Phase 1"
  description               = "Keyless GitHub Actions identities restricted by repository"

  depends_on = [google_project_service.required]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.workload_identity_provider_id
  display_name                       = "GitHub Actions OIDC"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  attribute_condition = "assertion.repository in ['${local.app_repo_full}','${local.platform_repo_full}']"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "app_wif" {
  service_account_id = google_service_account.app_ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${local.app_repo_full}"
}

resource "google_artifact_registry_repository_iam_member" "app_writer" {
  project    = var.project_id
  location   = google_artifact_registry_repository.bank.location
  repository = google_artifact_registry_repository.bank.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.app_ci.email}"
}
