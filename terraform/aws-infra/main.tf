locals {
  azs                = [for suffix in var.availability_zone_suffixes : "${var.aws_region}${suffix}"]
  app_repo_full      = "${var.github_owner}/${var.app_repository}"
  platform_repo_full = "${var.github_owner}/${var.platform_repository}"
  app_repo_subject   = "${var.github_owner}@${var.github_owner_id}/${var.app_repository}@${var.app_repository_id}"
  platform_repo_subject = (
    "${var.github_owner}@${var.github_owner_id}/${var.platform_repository}@${var.platform_repository_id}"
  )
  services = toset([
    "frontend",
    "userservice",
    "contacts",
    "balancereader",
    "ledgerwriter",
    "transactionhistory",
  ])
  common_tags = {
    Project   = "phase1-bank-cicd"
    ManagedBy = "Terraform"
    Owner     = "kdn10"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = local.azs
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.25.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = false
  enable_irsa                              = true

  # Keep key administration stable when Terraform runs locally or through GitHub OIDC.
  kms_key_administrators = [
    var.cluster_admin_principal_arn,
    aws_iam_role.github_terraform.arn,
  ]

  addons = {
    coredns                = { addon_version = var.eks_addon_versions["coredns"] }
    kube-proxy             = { addon_version = var.eks_addon_versions["kube-proxy"] }
    vpc-cni                = { addon_version = var.eks_addon_versions["vpc-cni"], before_compute = true }
    eks-pod-identity-agent = { addon_version = var.eks_addon_versions["eks-pod-identity-agent"], before_compute = true }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    application = {
      name           = var.node_group_name
      min_size       = 2
      max_size       = 4
      desired_size   = 2
      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      labels = {
        workload = "bank-app"
      }
    }
  }

  access_entries = {
    # Preserve the module's original state address while making the principal explicit.
    cluster_creator = {
      principal_arn = var.cluster_admin_principal_arn
      policy_associations = {
        admin = {
          policy_arn = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }

    github_terraform = {
      principal_arn = aws_iam_role.github_terraform.arn
      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
}

resource "aws_secretsmanager_secret" "runtime" {
  name                    = "${var.runtime_secret_prefix}/runtime"
  description             = "Runtime database and Redis connection values for Bank of Anthos"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret" "jwt" {
  name                    = "${var.runtime_secret_prefix}/jwt"
  description             = "Bank of Anthos RS256 private/public key pair"
  recovery_window_in_days = 0
}
