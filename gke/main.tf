data "http" "management_ip" {
  url = "https://ipinfo.io/ip"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Status code invalid"
    }
  }
}

data "google_client_config" "current" {}

locals {
  unique_id         = random_string.suffix.result
  gke_cluster_name  = "${var.gke_cluster_name}-${local.unique_id}"
  gke_nodepool_name = "standard"
  gke_subnet_name   = "gke-snet-${local.unique_id}"
  management_ip     = "${chomp(data.http.management_ip.response_body)}/32"
  network_name      = "vpc-${local.unique_id}"
}

###
# Generate random string id
###

resource "random_string" "suffix" {
  length  = 5
  lower   = true
  numeric = false
  special = false
  upper   = false
}

data "google_compute_zones" "available" {
  project = var.project
  region  = var.region
}

data "google_project" "current" {}
