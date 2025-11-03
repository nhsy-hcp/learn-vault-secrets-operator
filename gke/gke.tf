resource "google_service_account" "gke" {
  account_id   = "gke-${local.unique_id}"
  display_name = "GKE Service Account"
  description  = "Service account for GKE cluster nodes"
  project      = var.project
}

resource "google_project_iam_member" "gke" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/stackdriver.resourceMetadata.writer"
  ])
  project = var.project
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke.email}"
}

# GKE Autopilot doesn't support Vault CSI driver
# Release "vault" does not exist. Installing it now.
# Error: 1 error occurred:
#         * admission webhook "warden-validating.common-webhooks.networking.gke.io" denied the request: GKE Warden rejected the request because it violates one or more constraints.
# Violations details: {"[denied by autogke-no-write-mode-hostpath]":["hostPath volume providervol in container vault-csi-provider is accessed in write mode; disallowed in Autopilot."]}

# resource "google_container_cluster" "autopilot" {
#   name     = local.gke_cluster_name
#   location = var.region
#
#   enable_autopilot = true
#   networking_mode  = "VPC_NATIVE"
#
#   cluster_autoscaling {
#     auto_provisioning_defaults {
#       service_account = google_service_account.gke.email
#     }
#   }
#
#   gateway_api_config {
#     channel = "CHANNEL_STANDARD"
#   }
#
#   workload_identity_config {
#     workload_pool = "${var.project}.svc.id.goog"
#   }
#
#   private_cluster_config {
#     enable_private_nodes   = true
#     master_ipv4_cidr_block = "172.16.0.32/28"
#   }
#
#   master_authorized_networks_config {
#     cidr_blocks {
#       cidr_block = local.management_ip
#     }
#   }
#
#   network    = google_compute_network.default.self_link
#   subnetwork = google_compute_subnetwork.default["gke"].self_link
#
#   deletion_protection = false
#
#   timeouts {
#     delete = "30m"
#   }
# }

#------------------------------------------------------------------------------
# GKE cluster
#------------------------------------------------------------------------------
resource "google_container_cluster" "default" {
  name    = local.gke_cluster_name
  project = var.project

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  network    = google_compute_network.default.self_link
  subnetwork = google_compute_subnetwork.default["gke"].self_link

  release_channel {
    channel = var.gke_release_channel
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.32/28"

    master_global_access_config {
      enabled = false
    }
  }

  master_authorized_networks_config {
    gcp_public_cidrs_access_enabled = true

    cidr_blocks {
      cidr_block = local.management_ip
    }
  }

  enable_l4_ilb_subsetting = var.gke_l4_ilb_subsetting_enabled

  addons_config {
    http_load_balancing {
      disabled = var.gke_http_load_balancing_disabled
    }
  }

  workload_identity_config {
    workload_pool = "${var.project}.svc.id.goog"
  }

  logging_service = "logging.googleapis.com/kubernetes"
}

# ------------------------------------------------------------------------------
# GKE node pool
# ------------------------------------------------------------------------------
resource "google_container_node_pool" "standard" {

  name       = local.gke_nodepool_name
  cluster    = google_container_cluster.default.id
  node_count = var.gke_node_count

  autoscaling {
    min_node_count = var.gke_node_count
    max_node_count = var.gke_node_count * 3
  }

  network_config {
    enable_private_nodes = true
  }

  node_config {
    disk_type    = "pd-ssd"
    machine_type = var.gke_node_type
    preemptible  = var.gke_node_preemptible

    service_account = google_service_account.gke.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
