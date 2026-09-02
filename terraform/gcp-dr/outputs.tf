output "cluster_name" {
  value = google_container_cluster.dr.name
}

output "cluster_location" {
  value = google_container_cluster.dr.location
}

output "cluster_endpoint" {
  value = google_container_cluster.dr.endpoint
}

output "cluster_ca_certificate" {
  value     = google_container_cluster.dr.master_auth[0].cluster_ca_certificate
  sensitive = true
}

output "node_pool_name" {
  value = google_container_node_pool.pilot_light.name
}

output "dr_control_service_account" {
  value = google_service_account.dr_control.email
}

output "terraform_service_account" {
  value = google_service_account.terraform.email
}

output "secret_reader_service_account" {
  value = google_service_account.secret_reader.email
}
