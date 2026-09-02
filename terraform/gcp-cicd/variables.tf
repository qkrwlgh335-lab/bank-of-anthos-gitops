variable "project_id" {
  type    = string
  default = "kdt4-1-506106"
}

variable "approved_project_id" {
  description = "Safety lock: approved GCP project"
  type        = string
  default     = "kdt4-1-506106"
}

variable "region" {
  type    = string
  default = "asia-northeast3"
}

variable "github_owner" {
  type    = string
  default = "qkrwlgh335-lab"
}

variable "app_repository" {
  type    = string
  default = "bank-of-anthos-app"
}

variable "platform_repository" {
  type    = string
  default = "bank-of-anthos-gitops"
}

variable "artifact_repository" {
  type    = string
  default = "bank-of-anthos"
}

variable "app_ci_service_account_id" {
  description = "Project-unique CI service account ID"
  type        = string
  default     = "github-bank-app-ci"
}

variable "workload_identity_pool_id" {
  description = "Project-unique GitHub Workload Identity Pool ID"
  type        = string
  default     = "github-phase1"
}

variable "workload_identity_provider_id" {
  description = "Provider ID inside the selected Workload Identity Pool"
  type        = string
  default     = "github-provider"
}

variable "adopt_existing_resources" {
  description = "Import the pre-existing Phase 1 registry, service account, and WIF resources instead of trying to recreate their unique names"
  type        = bool
  default     = false
}
