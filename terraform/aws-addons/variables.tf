variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "state_bucket" {
  type    = string
  default = "phase1-cicd-tfstate-558807819624"
}

variable "infra_state_key" {
  type    = string
  default = "aws-infra/terraform.tfstate"
}
