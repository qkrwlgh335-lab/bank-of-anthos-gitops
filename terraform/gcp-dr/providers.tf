provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "current" {
  project_id = var.project_id

  lifecycle {
    postcondition {
      condition     = self.project_id == var.approved_project_id
      error_message = "Refusing to manage DR resources outside project ${var.approved_project_id}."
    }
  }
}

data "terraform_remote_state" "cicd" {
  backend = "gcs"
  config = {
    bucket = var.cicd_state_bucket
    prefix = var.cicd_state_prefix
  }
}
