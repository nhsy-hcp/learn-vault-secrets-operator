#------ general -----

output "region" {
  description = "AWS region"
  value       = var.region
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster EKS endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id_eks_cluster" {
  description = "EKS cluster control plane SG"
  value       = module.eks.cluster_security_group_id
}

output "eks_node_security_group_id_cluster" {
  description = "EKS cluster nodes SG"
  value       = module.eks.node_security_group_id
}

output "eks_cluster_kube_context" {
  value = "arn:aws:eks:${var.region}:${var.aws_account_id}:cluster/${var.eks_cluster_name}"
}


output "acm_certificate_arn" {
  value = aws_acm_certificate.default.arn
}

output "echoserver_url" {
  value = "https://${local.echoserver_fqdn}"
}

output "vault_url" {
  value = "https://${local.vault_fqdn}"
}


output "eks_ca_certificate" {
  value = module.eks.cluster_certificate_authority_data
}

output "eks_host" {
  value = module.eks.cluster_endpoint
}

output "eks_name" {
  value = module.eks.cluster_name
}
