output "project" {
  value = var.project
}
output "region" {
  value = var.region
}

output "gke_cluster_name" {
  value = local.gke_cluster_name
}