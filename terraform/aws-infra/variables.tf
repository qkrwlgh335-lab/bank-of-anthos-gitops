variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "phase1-bank-eks"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.35"
}

variable "vpc_cidr" {
  description = "CIDR for the isolated EKS VPC"
  type        = string
  default     = "10.40.0.0/16"
}

variable "node_instance_types" {
  description = "Managed node group instance types"
  type        = list(string)
  default     = ["t3.medium"]
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

variable "ecr_prefix" {
  type    = string
  default = "bank-app"
}

variable "rds_security_group_id" {
  description = "Existing PoC RDS security group; NAT EIP /32 is added for app traffic"
  type        = string
  default     = "sg-0aad5ded42f47ee46"
}
