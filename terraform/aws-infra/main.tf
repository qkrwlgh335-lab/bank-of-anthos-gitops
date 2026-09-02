locals {
  azs                = ["${var.aws_region}a", "${var.aws_region}c"]
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

  name = "phase1-bank-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  public_subnets  = ["10.40.0.0/24", "10.40.1.0/24"]
  private_subnets = ["10.40.10.0/24", "10.40.11.0/24"]

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
    coredns                = { most_recent = true }
    kube-proxy             = { most_recent = true }
    vpc-cni                = { most_recent = true, before_compute = true }
    eks-pod-identity-agent = { most_recent = true, before_compute = true }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    application = {
      name           = "phase1-bank-app"
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

resource "aws_vpc_security_group_ingress_rule" "rds_from_eks_nat" {
  count = var.rds_security_group_id == "" ? 0 : 1

  security_group_id = var.rds_security_group_id
  description       = "PostgreSQL from phase1 EKS fixed NAT egress IP"
  cidr_ipv4         = "${module.vpc.nat_public_ips[0]}/32"
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
}

resource "aws_secretsmanager_secret" "runtime" {
  name                    = "phase1/bank-app/runtime"
  description             = "Runtime database and Redis connection values for Bank of Anthos"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret" "jwt" {
  name                    = "phase1/bank-app/jwt"
  description             = "Bank of Anthos RS256 private/public key pair"
  recovery_window_in_days = 0
}
