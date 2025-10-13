module "aws_vpc_cni_ipv4_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name = "aws-vpc-cni-ipv4"

  attach_aws_vpc_cni_policy = true
  aws_vpc_cni_enable_ipv4   = true
}

module "aws_ebs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name = "aws-ebs-csi-driver"

  attach_aws_ebs_csi_policy = true
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~>21.0"

  name               = var.eks_cluster_name
  kubernetes_version = var.eks_k8s_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoint_public_access = true

  # restrict access to management ip address
  endpoint_public_access_cidrs = concat([local.management_ip], var.mgmt_cidrs)

  create_security_group      = true
  create_node_security_group = true

  #  create_cloudwatch_log_group = false
  enabled_log_types                      = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = 1

  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
      pod_identity_association = [{
        role_arn        = module.aws_vpc_cni_ipv4_pod_identity.iam_role_arn
        service_account = "aws-node"
      }]
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
          WARM_IP_TARGET           = "5"
        }
      })
    }
    # removed to a separate resource to avoid race condition with coredns
    # aws-ebs-csi-driver = {
    #   depends_on = ["coredns"]
    #   # most_recent = true
    #   pod_identity_association = [{
    #     role_arn        = module.aws_ebs_csi_pod_identity.iam_role_arn
    #     service_account = "ebs-csi-controller-sa"
    #   }]
    # }
  }

  # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
  }

  # Enable cluster access management
  enable_cluster_creator_admin_permissions = true

  # EKS Managed Node Group(s)
  eks_managed_node_groups = {
    blue = {
      name           = var.eks_cluster_name
      disk_size      = var.eks_node_workers["disk_size"]
      instance_types = var.eks_node_instance_types
      capacity_type  = var.eks_node_capacity_type

      min_size     = var.eks_node_workers["min_size"]
      max_size     = var.eks_node_workers["max_size"]
      desired_size = var.eks_node_workers["desired_size"]

      key_name                   = var.eks_managed_node_groups_ssh_key_pair
      iam_role_attach_cni_policy = true
    }
  }
}

resource "aws_eks_addon" "aws-ebs-csi-driver" {
  cluster_name = module.eks.cluster_name
  addon_name   = "aws-ebs-csi-driver"

  pod_identity_association {
    role_arn        = module.aws_ebs_csi_pod_identity.iam_role_arn
    service_account = "ebs-csi-controller-sa"
  }

  depends_on = [module.eks]
}