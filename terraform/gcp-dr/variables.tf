variable "project_id" {
  type    = string
  default = "kdt4-1-506106"
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

variable "node_pool_name" {
  type    = string
  default = "pilot-light"
}

variable "node_machine_type" {
  type    = string
  default = "e2-standard-2"
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
