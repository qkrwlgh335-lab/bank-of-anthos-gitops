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

variable "cluster_admin_principal_arn" {
  description = "Stable operator principal that retains EKS and KMS administration regardless of who runs Terraform"
  type        = string
  default     = "arn:aws:iam::558807819624:user/kdn10"
}

variable "github_owner" {
  type    = string
  default = "qkrwlgh335-lab"
}

variable "github_owner_id" {
  description = "Immutable GitHub owner ID present in this account's customized OIDC subject"
  type        = string
  default     = "306914305"
}

variable "app_repository" {
  type    = string
  default = "bank-of-anthos-app"
}

variable "app_repository_id" {
  description = "Immutable GitHub application repository ID present in the OIDC subject"
  type        = string
  default     = "1353862115"
}

variable "platform_repository" {
  type    = string
  default = "bank-of-anthos-gitops"
}

variable "platform_repository_id" {
  description = "Immutable GitHub platform repository ID present in the OIDC subject"
  type        = string
  default     = "1353862571"
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
