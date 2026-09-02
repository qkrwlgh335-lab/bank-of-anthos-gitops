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

data "aws_caller_identity" "current" {
  lifecycle {
    postcondition {
      condition     = self.account_id == var.aws_account_id
      error_message = "Refusing to manage DR data resources outside AWS account ${var.aws_account_id}."
    }
  }
}

data "google_project" "current" {
  project_id = var.gcp_project_id

  lifecycle {
    postcondition {
      condition     = self.project_id == var.gcp_project_id
      error_message = "Authenticated Google credentials cannot access the approved project ${var.gcp_project_id}."
    }
  }
}
