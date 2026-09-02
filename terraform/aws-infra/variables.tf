variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "aws_account_id" {
  description = "Safety lock: the only AWS account this Phase 1 stack may change"
  type        = string
  default     = "558807819624"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "phase1-bank-eks"
}

variable "vpc_name" {
  description = "Environment-unique VPC name"
  type        = string
  default     = "phase1-bank-vpc"
}

variable "node_group_name" {
  description = "Environment-unique managed node group name"
  type        = string
  default     = "phase1-bank-app"
}

variable "resource_name_prefix" {
  description = "Environment-unique prefix for account-global IAM resources"
  type        = string
  default     = "phase1"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.resource_name_prefix))
    error_message = "resource_name_prefix may contain only lowercase letters, digits, and hyphens."
  }
}

variable "runtime_secret_prefix" {
  description = "Environment-unique Secrets Manager path"
  type        = string
  default     = "phase1/bank-app"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.35"
}

variable "eks_addon_versions" {
  description = "EKS add-on versions validated for kubernetes_version; update deliberately with the cluster version"
  type        = map(string)

  validation {
    condition = alltrue([
      for name in ["coredns", "kube-proxy", "vpc-cni", "eks-pod-identity-agent"] :
      contains(keys(var.eks_addon_versions), name) && length(var.eks_addon_versions[name]) > 0
    ])
    error_message = "eks_addon_versions must include non-empty coredns, kube-proxy, vpc-cni, and eks-pod-identity-agent versions."
  }
}

variable "vpc_cidr" {
  description = "CIDR for the isolated EKS VPC"
  type        = string
  default     = "10.40.0.0/16"
}

variable "availability_zone_suffixes" {
  description = "Two AZ suffixes used by the Phase 1 workload"
  type        = list(string)
  default     = ["a", "c"]

  validation {
    condition     = length(var.availability_zone_suffixes) == 2 && length(distinct(var.availability_zone_suffixes)) == 2
    error_message = "Exactly two distinct availability-zone suffixes are required."
  }
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.40.0.0/24", "10.40.1.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2 && alltrue([for cidr in var.public_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Exactly two valid public subnet CIDRs are required."
  }
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.40.10.0/24", "10.40.11.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) == 2 && alltrue([for cidr in var.private_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Exactly two valid private subnet CIDRs are required."
  }
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
