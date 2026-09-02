provider "google" {
  project = var.project_id
  region  = var.region
}

data "terraform_remote_state" "dr" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = var.dr_state_prefix
  }
}

data "google_client_config" "current" {}

provider "kubernetes" {
  host                   = "https://${data.terraform_remote_state.dr.outputs.cluster_endpoint}"
  token                  = data.google_client_config.current.access_token
  cluster_ca_certificate = base64decode(data.terraform_remote_state.dr.outputs.cluster_ca_certificate)
}

provider "helm" {
  kubernetes = {
    host                   = "https://${data.terraform_remote_state.dr.outputs.cluster_endpoint}"
    token                  = data.google_client_config.current.access_token
    cluster_ca_certificate = base64decode(data.terraform_remote_state.dr.outputs.cluster_ca_certificate)
  }
}
