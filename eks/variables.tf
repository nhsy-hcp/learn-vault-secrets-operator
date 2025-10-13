variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.64.0.0/16"
}

variable "eks_k8s_version" {
  type    = string
  default = "1.34"
}

variable "eks_cluster_name" {
  type    = string
  default = "eks-hcp"
}

# Managed nodes group parameters
variable "eks_node_workers" {
  type = object({
    min_size     = number
    max_size     = number
    desired_size = number
    disk_size    = number
  })

  default = {
    min_size     = 1
    max_size     = 6
    desired_size = 3
    disk_size    = 50
  }
}

variable "eks_node_instance_types" {
  type    = list(string)
  default = ["m5.large", "m4.large"]
}

variable "eks_node_capacity_type" {
  type    = string
  default = "ON_DEMAND" #"ON_DEMAND" or "SPOT"
}

variable "eks_managed_node_groups_ssh_key_pair" {
  type    = string
  default = null
}

# IAM for ebs-csi-controller
variable "ebs_csi_controller_role_name" {
  type    = string
  default = "ebs-csi-controller-role"
}

variable "aws_account_id" {
  type = string
}

variable "owner" {
  type = string
}

variable "domain" {
  type = string
}

variable "mgmt_cidrs" {
  type    = list(string)
  default = []
}