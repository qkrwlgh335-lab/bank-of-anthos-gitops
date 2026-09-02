variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "aws_account_id" {
  description = "Safety lock: approved AWS account"
  type        = string
  default     = "558807819624"
}

variable "state_bucket" {
  type    = string
  default = "phase1-cicd-tfstate-558807819624"
}

variable "infra_state_key" {
  type    = string
  default = "aws-infra/terraform.tfstate"
}
