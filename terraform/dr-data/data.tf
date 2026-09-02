locals {
  aws_tags = {
    Project   = "phase1-bank-dr"
    ManagedBy = "Terraform"
    Owner     = "kdn10"
    Scope     = "dr-data"
  }
  cloudsql_private_service_cidr = try(
    data.terraform_remote_state.gcp_dr.outputs.cloudsql_private_service_cidr,
    var.cloudsql_private_service_cidr,
  )
  gcp_network_name = try(
    data.terraform_remote_state.gcp_dr.outputs.network_name,
    var.gcp_network_name,
  )
  gcp_router_name = try(
    data.terraform_remote_state.gcp_dr.outputs.router_name,
    var.gcp_router_name,
  )
  gcp_dr_control_service_account = data.terraform_remote_state.gcp_dr.outputs.dr_control_service_account
}

data "terraform_remote_state" "gcp_dr" {
  backend = "gcs"
  config = {
    bucket = var.gcp_state_bucket
    prefix = var.gcp_dr_state_prefix
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

data "aws_security_group" "eks_nodes" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.primary.id]
  }

  filter {
    name   = "tag:Name"
    values = ["${var.aws_eks_cluster_name}-node"]
  }

  filter {
    name   = "tag:kubernetes.io/cluster/${var.aws_eks_cluster_name}"
    values = ["owned"]
  }
}

data "google_compute_network" "dr" {
  name    = local.gcp_network_name
  project = var.gcp_project_id
}
