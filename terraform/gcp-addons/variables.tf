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

variable "state_bucket" {
  type    = string
  default = "phase1-cicd-tfstate-kdt4-1-506106"
}

variable "dr_state_prefix" {
  type    = string
  default = "gcp-dr"
}
