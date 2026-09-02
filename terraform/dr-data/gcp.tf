resource "google_compute_global_address" "cloudsql_private_service" {
  name          = "${var.resource_name_prefix}-cloudsql-range"
  project       = var.gcp_project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = cidrhost(local.cloudsql_private_service_cidr, 0)
  prefix_length = tonumber(split("/", local.cloudsql_private_service_cidr)[1])
  network       = data.google_compute_network.dr.id
}

resource "google_service_networking_connection" "cloudsql" {
  network                 = data.google_compute_network.dr.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.cloudsql_private_service.name]
}

resource "google_compute_network_peering_routes_config" "cloudsql" {
  project = var.gcp_project_id
  network = data.google_compute_network.dr.name
  peering = google_service_networking_connection.cloudsql.peering

  import_custom_routes = true
  export_custom_routes = true
}

resource "google_sql_database_instance" "standby" {
  name             = var.cloudsql_instance_name
  project          = var.gcp_project_id
  region           = var.gcp_region
  database_version = "POSTGRES_16"

  settings {
    tier              = var.cloudsql_tier
    edition           = "ENTERPRISE"
    availability_type = "ZONAL"
    disk_type         = "PD_SSD"
    disk_size         = 10
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = data.google_compute_network.dr.id
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled                        = false
      point_in_time_recovery_enabled = false
    }

    insights_config {
      query_insights_enabled = false
    }

    user_labels = {
      project    = "phase1-bank-dr"
      managed-by = "terraform"
      role       = "pilot-light-standby"
    }
  }

  deletion_protection = false

  depends_on = [
    google_compute_network_peering_routes_config.cloudsql,
    google_service_networking_connection.cloudsql,
  ]

  lifecycle {
    precondition {
      condition     = data.google_project.current.project_id == var.gcp_project_id
      error_message = "Refusing to create Cloud SQL outside the approved GCP project."
    }
  }
}

resource "google_secret_manager_secret" "dms_source" {
  project   = var.gcp_project_id
  secret_id = "${var.resource_name_prefix}-dms-source"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "cloudsql_admin" {
  project   = var.gcp_project_id
  secret_id = "${var.resource_name_prefix}-cloudsql-admin"

  replication {
    auto {}
  }
}
