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

variable "node_zone" {
  description = "Single pilot-light node location; add zones before production DR"
  type        = string
  default     = "asia-northeast3-a"
}

variable "cluster_name" {
  type    = string
  default = "phase1-bank-gke"
}

variable "network_name" {
  type    = string
  default = "phase1-bank-dr-vpc"
}

variable "subnetwork_name" {
  type    = string
  default = "phase1-bank-gke-subnet"
}

variable "router_name" {
  type    = string
  default = "phase1-bank-dr-router"
}

variable "nat_name" {
  type    = string
  default = "phase1-bank-dr-nat"
}

variable "node_pool_name" {
  type    = string
  default = "pilot-light"
}

variable "node_machine_type" {
  type    = string
  default = "e2-standard-2"
}

variable "node_service_account_id" {
  type    = string
  default = "phase1-gke-nodes"
}

variable "secret_reader_service_account_id" {
  type    = string
  default = "bank-dr-secrets"
}

variable "dr_control_service_account_id" {
  type    = string
  default = "github-bank-dr-control"
}

variable "terraform_service_account_id" {
  type    = string
  default = "github-bank-terraform"
}

variable "runtime_secret_id" {
  type    = string
  default = "phase1-bank-app-runtime"
}

variable "jwt_secret_id" {
  type    = string
  default = "phase1-bank-app-jwt"
}

variable "gke_subnet_cidr" {
  type    = string
  default = "10.50.0.0/20"

  validation {
    condition     = can(cidrhost(var.gke_subnet_cidr, 0))
    error_message = "gke_subnet_cidr must be a valid CIDR."
  }
}

variable "gke_services_cidr" {
  type    = string
  default = "10.51.0.0/20"

  validation {
    condition     = can(cidrhost(var.gke_services_cidr, 0))
    error_message = "gke_services_cidr must be a valid CIDR."
  }
}

variable "gke_pods_cidr" {
  type    = string
  default = "10.52.0.0/16"

  validation {
    condition     = can(cidrhost(var.gke_pods_cidr, 0))
    error_message = "gke_pods_cidr must be a valid CIDR."
  }
}

variable "cloudsql_private_service_cidr" {
  type    = string
  default = "10.53.0.0/24"

  validation {
    condition     = can(cidrhost(var.cloudsql_private_service_cidr, 0))
    error_message = "cloudsql_private_service_cidr must be a valid CIDR."
  }
}

variable "gke_master_cidr" {
  type    = string
  default = "172.16.0.0/28"

  validation {
    condition     = can(cidrhost(var.gke_master_cidr, 0))
    error_message = "gke_master_cidr must be a valid CIDR."
  }
}

variable "github_owner" {
  type    = string
  default = "qkrwlgh335-lab"
}

variable "platform_repository" {
  type    = string
  default = "bank-of-anthos-gitops"
}

variable "workload_identity_pool_name" {
  description = "Existing GitHub Workload Identity Pool created by gcp-cicd"
  type        = string
  default     = "projects/465472304431/locations/global/workloadIdentityPools/github-phase1"
}

variable "cicd_state_bucket" {
  type    = string
  default = "phase1-cicd-tfstate-kdt4-1-506106"
}

variable "cicd_state_prefix" {
  type    = string
  default = "gcp-cicd"
}
