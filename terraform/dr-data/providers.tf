provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.aws_tags
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

data "aws_caller_identity" "current" {}

data "google_project" "current" {
  project_id = var.gcp_project_id
}
