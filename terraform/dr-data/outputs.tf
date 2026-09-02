output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "rds_identifier" {
  value = aws_db_instance.primary.identifier
}

output "rds_endpoint" {
  value = aws_db_instance.primary.address
}

output "eks_node_security_group_id" {
  description = "Worker-node security group permitted to reach the private RDS endpoint"
  value       = data.aws_security_group.eks_nodes.id
}

output "rds_master_secret_arn" {
  value     = aws_db_instance.primary.master_user_secret[0].secret_arn
  sensitive = true
}

output "rds_app_secret_arn" {
  value = aws_secretsmanager_secret.app_database.arn
}

output "rds_dms_secret_arn" {
  value = aws_secretsmanager_secret.dms_source.arn
}

output "gcp_project_id" {
  value = data.google_project.current.project_id
}

output "cloudsql_instance_name" {
  value = google_sql_database_instance.standby.name
}

output "cloudsql_private_ip" {
  value = google_sql_database_instance.standby.private_ip_address
}

output "gcp_dms_secret_id" {
  value = google_secret_manager_secret.dms_source.secret_id
}

output "gcp_cloudsql_admin_secret_id" {
  value = google_secret_manager_secret.cloudsql_admin.secret_id
}

output "aws_vpn_connection_ids" {
  value = [
    aws_vpn_connection.gcp_interface_0.id,
    aws_vpn_connection.gcp_interface_1.id,
  ]
}

output "gcp_vpn_gateway_name" {
  value = google_compute_ha_vpn_gateway.aws.name
}
