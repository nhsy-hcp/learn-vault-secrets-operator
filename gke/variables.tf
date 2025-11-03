variable "project" {
  description = "Project ID to deploy into"
  type        = string
}

variable "region" {
  description = "The region to deploy to"
  default     = "europe-west1"
  type        = string
}

variable "subnet_cidr" {
  type    = string
  default = "10.64.0.0/20"
}

variable "routing_mode" {
  description = "The network routing mode"
  type        = string
  default     = "REGIONAL"
}

variable "auto_create_subnetworks" {
  description = "When set to true, the network is created in 'auto subnet mode' and it will create a subnet for each region automatically across the 10.128.0.0/9 address range. When set to false, the network is created in 'custom subnet mode' so the user can explicitly connect subnetwork resources"
  type        = bool
  default     = false
}

variable "delete_default_internet_gateway_routes" {
  description = "If set, ensure that all routes within the network specified whose names begin with 'default-route' and with a next hop of 'default-internet-gateway' are deleted"
  type        = bool
  default     = false
}

variable "network_description" {
  description = "An optional description of this resource. The resource must be recreated to modify this field"
  type        = string
  default     = null
}

variable "router_name" {
  description = "Router name"
  type        = string
  default     = "cr-nat-router"
}

variable "router_nat_name" {
  description = "Name for the router NAT gateway"
  type        = string
  default     = "rn-nat-gateway"
}

#------------------------------------------------------------------------------
# GKE
#------------------------------------------------------------------------------
variable "gke_cluster_name" {
  type        = string
  description = "Name of GKE cluster to create."
  default     = "vault"
}

variable "gke_release_channel" {
  type        = string
  description = "The channel to use for how frequent Kubernetes updates and features are received."
  default     = "REGULAR"
}

variable "master_ipv4_cidr_block" {
  type        = string
  description = "GKE control plane CIDR block."
  default     = "172.16.0.32/28"

}

variable "gke_l4_ilb_subsetting_enabled" {
  type        = bool
  description = "Boolean to enable L4 ILB subsetting on GKE cluster."
  default     = true
}

variable "gke_http_load_balancing_disabled" {
  type        = bool
  description = "Boolean to enable HTTP load balancing on GKE cluster."
  default     = false
}

variable "gke_node_count" {
  type        = number
  description = "Number of GKE nodes per zone"
  default     = 1
}

variable "gke_node_type" {
  type        = string
  description = "Size/machine type of GKE nodes."
  default     = "e2-standard-2"
}

variable "gke_node_preemptible" {
  type        = bool
  description = "Preemptible GKE nodes."
  default     = false
}