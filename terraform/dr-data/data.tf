locals {
  aws_tags = {
    Project   = "phase1-bank-dr"
    ManagedBy = "Terraform"
    Owner     = "kdn10"
    Scope     = "dr-data"
  }
}

data "aws_vpc" "primary" {
  filter {
    name   = "tag:Name"
    values = [var.aws_vpc_name]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.primary.id]
  }

  filter {
    name   = "tag:kubernetes.io/role/internal-elb"
    values = ["1"]
  }
}

data "aws_route_tables" "private" {
  vpc_id = data.aws_vpc.primary.id

  filter {
    name   = "tag:Name"
    values = ["${var.aws_vpc_name}-private"]
  }
}

data "aws_eks_cluster" "primary" {
  name = var.aws_eks_cluster_name
}

data "google_compute_network" "dr" {
  name    = var.gcp_network_name
  project = var.gcp_project_id
}
