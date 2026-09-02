locals {
  platform_repo = "${var.github_owner}/${var.platform_repository}"
  required_apis = toset([
    "artifactregistry.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "datamigration.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "sqladmin.googleapis.com",
    "sts.googleapis.com",
  ])
  node_roles = toset([
    "roles/artifactregistry.reader",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
  ])
  terraform_roles = toset([
    "roles/compute.networkAdmin",
    "roles/container.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/secretmanager.admin",
    "roles/serviceusage.serviceUsageAdmin",
  ])
  dr_control_roles = toset([
    "roles/artifactregistry.reader",
    "roles/cloudsql.admin",
    "roles/container.clusterAdmin",
    "roles/datamigration.admin",
    "roles/secretmanager.viewer",
  ])
}

resource "google_project_service" "required" {
  for_each = local.required_apis

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_network" "dr" {
  name                    = "phase1-bank-dr-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.required]
}

resource "google_compute_subnetwork" "gke" {
  name          = "phase1-bank-gke-subnet"
  region        = var.region
  network       = google_compute_network.dr.id
  ip_cidr_range = "10.50.0.0/20"

  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = "10.52.0.0/16"
  }

  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = "10.51.0.0/20"
  }
}

resource "google_compute_router" "dr" {
  name    = "phase1-bank-dr-router"
  region  = var.region
  network = google_compute_network.dr.id
}

resource "google_compute_router_nat" "dr" {
  name                               = "phase1-bank-dr-nat"
  router                             = google_compute_router.dr.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.gke.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_service_account" "gke_nodes" {
  account_id   = "phase1-gke-nodes"
  display_name = "Phase 1 GKE pilot-light nodes"
}

resource "google_project_iam_member" "gke_nodes" {
  for_each = local.node_roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_container_cluster" "dr" {
  name     = var.cluster_name
  location = var.region

  node_locations = [var.node_zone]
  network        = google_compute_network.dr.id
  subnetwork     = google_compute_subnetwork.gke.id

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  release_channel {
    channel = "REGULAR"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"

    master_global_access_config {
      enabled = true
    }
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
  }

  enable_shielded_nodes = true
  networking_mode       = "VPC_NATIVE"

  depends_on = [
    google_compute_router_nat.dr,
    google_project_service.required,
  ]
}

resource "google_container_node_pool" "pilot_light" {
  name     = var.node_pool_name
  cluster  = google_container_cluster.dr.id
  location = var.region

  node_count = 1

  node_config {
    machine_type    = var.node_machine_type
    disk_type       = "pd-balanced"
    disk_size_gb    = 50
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = {
      workload = "pilot-light-control-plane"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  depends_on = [google_project_iam_member.gke_nodes]
}

resource "google_secret_manager_secret" "runtime" {
  secret_id = "phase1-bank-app-runtime"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret" "jwt" {
  secret_id = "phase1-bank-app-jwt"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required]
}

resource "google_service_account" "secret_reader" {
  account_id   = "bank-dr-secrets"
  display_name = "Bank DR External Secrets reader"
}

resource "google_service_account_iam_member" "secret_reader_workload_identity" {
  service_account_id = google_service_account.secret_reader.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[bank-dr/bank-dr-secret-reader]"

  depends_on = [google_container_cluster.dr]
}

resource "google_secret_manager_secret_iam_member" "runtime_reader" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.runtime.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.secret_reader.email}"
}

resource "google_secret_manager_secret_iam_member" "jwt_reader" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.jwt.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.secret_reader.email}"
}

resource "google_service_account" "dr_control" {
  account_id   = "github-bank-dr-control"
  display_name = "GitHub approved GCP DR control"
}

resource "google_service_account_iam_member" "dr_control_wif" {
  service_account_id = google_service_account.dr_control.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${var.workload_identity_pool_name}/attribute.repository/${local.platform_repo}"
}

resource "google_project_iam_member" "dr_control" {
  for_each = local.dr_control_roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.dr_control.email}"
}

resource "google_service_account" "terraform" {
  account_id   = "github-bank-terraform"
  display_name = "GitHub Terraform for GCP DR"
}

resource "google_service_account_iam_member" "terraform_wif" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${var.workload_identity_pool_name}/attribute.repository/${local.platform_repo}"
}

resource "google_project_iam_member" "terraform" {
  for_each = local.terraform_roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_storage_bucket_iam_member" "terraform_state" {
  bucket = "phase1-cicd-tfstate-kdt4-1-506106"
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.terraform.email}"
}
