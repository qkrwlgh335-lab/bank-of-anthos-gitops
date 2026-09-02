variable "aws_account_id" {
  description = "Safety lock: the only AWS account this stack may change"
  type        = string
  default     = "558807819624"
}

variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "aws_vpc_name" {
  type    = string
  default = "phase1-bank-vpc"
}

variable "aws_eks_cluster_name" {
  type    = string
  default = "phase1-bank-eks"
}

variable "rds_identifier" {
  type    = string
  default = "phase1-bank-postgres"
}

variable "rds_engine_version" {
  description = "Bank of Anthos database major/minor used for this PoC"
  type        = string
  default     = "16.14"
}

variable "rds_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "gcp_project_id" {
  description = "Safety lock: the only GCP project this stack may change"
  type        = string
  default     = "kdt4-1-506106"
}

variable "gcp_region" {
  type    = string
  default = "asia-northeast3"
}

variable "gcp_network_name" {
  type    = string
  default = "phase1-bank-dr-vpc"
}

variable "gcp_router_name" {
  type    = string
  default = "phase1-bank-dr-router"
}

variable "cloudsql_instance_name" {
  type    = string
  default = "phase1-bank-dr-postgres"
}

variable "cloudsql_tier" {
  description = "Low-cost pilot-light tier; not an SLA production tier"
  type        = string
  default     = "db-g1-small"
}

variable "cloudsql_private_service_cidr" {
  description = "Private Service Access range exported across the VPN for Cloud SQL/DMS"
  type        = string
  default     = "10.53.0.0/24"
}

variable "gcp_router_asn" {
  type    = number
  default = 64514
}

variable "aws_router_asn" {
  type    = number
  default = 64512
}
