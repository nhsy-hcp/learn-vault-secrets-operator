resource "google_compute_project_default_network_tier" "default" {
  network_tier = "PREMIUM"
}

###
# Create vpc network
###

resource "google_compute_network" "default" {
  name                            = local.network_name
  auto_create_subnetworks         = var.auto_create_subnetworks
  routing_mode                    = var.routing_mode
  project                         = var.project
  description                     = var.network_description
  delete_default_routes_on_create = var.delete_default_internet_gateway_routes
}

###
# Create subnets
###
resource "google_compute_subnetwork" "default" {
  for_each = {
    gke = {
      subnet_name                      = local.gke_subnet_name
      subnet_cidr                      = var.subnet_cidr
      subnet_region                    = var.region
      subnet_private_access            = "true"
      subnet_flow_logs                 = "true"
      subnet_flow_logs_metadata_fields = null
      subnet_flow_logs_filter          = null
      subnet_flow_logs_interval        = "INTERVAL_10_MIN"
      subnet_flow_logs_sampling        = 0.7
      subnet_flow_logs_metadata        = "INCLUDE_ALL_METADATA"
    }
  }

  name                     = each.value.subnet_name
  ip_cidr_range            = each.value.subnet_cidr
  region                   = each.value.subnet_region
  private_ip_google_access = lookup(each.value, "subnet_private_access", "false")

  dynamic "log_config" {
    for_each = coalesce(lookup(each.value, "subnet_flow_logs", null), false) ? [{
      aggregation_interval = each.value.subnet_flow_logs_interval
      flow_sampling        = each.value.subnet_flow_logs_sampling
      metadata             = each.value.subnet_flow_logs_metadata
      filter_expr          = each.value.subnet_flow_logs_filter
      metadata_fields      = each.value.subnet_flow_logs_metadata_fields
    }] : []
    content {
      aggregation_interval = log_config.value.aggregation_interval
      flow_sampling        = log_config.value.flow_sampling
      metadata             = log_config.value.metadata
      filter_expr          = log_config.value.filter_expr
      metadata_fields      = log_config.value.metadata == "CUSTOM_METADATA" ? log_config.value.metadata_fields : null
    }
  }

  network     = google_compute_network.default.self_link
  project     = var.project
  description = lookup(each.value, "description", null)
  purpose     = lookup(each.value, "purpose", null)
  role        = lookup(each.value, "role", null)

  lifecycle {
    ignore_changes = [
      secondary_ip_range # Ignore changes to secondary ranges for gke autopilot
    ]
  }
}


###
# Create cloud router and nat gateway
###
resource "google_compute_router" "router" {
  name    = var.router_name
  network = google_compute_network.default.self_link
  region  = var.region
  project = var.project
}

resource "google_compute_router_nat" "nat" {
  name                               = var.router_nat_name
  project                            = var.project
  region                             = var.region
  router                             = google_compute_router.router.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}