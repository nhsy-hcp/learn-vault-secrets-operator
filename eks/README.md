<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.36 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3.1 |
| <a name="requirement_http"></a> [http](#requirement\_http) | ~> 3.5 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.20.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.1.0 |
| <a name="provider_http"></a> [http](#provider\_http) | 3.5.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_aws_ebs_csi_pod_identity"></a> [aws\_ebs\_csi\_pod\_identity](#module\_aws\_ebs\_csi\_pod\_identity) | terraform-aws-modules/eks-pod-identity/aws | ~> 2.0 |
| <a name="module_aws_lb_controller_pod_identity"></a> [aws\_lb\_controller\_pod\_identity](#module\_aws\_lb\_controller\_pod\_identity) | terraform-aws-modules/eks-pod-identity/aws | ~> 2.0 |
| <a name="module_aws_vpc_cni_ipv4_pod_identity"></a> [aws\_vpc\_cni\_ipv4\_pod\_identity](#module\_aws\_vpc\_cni\_ipv4\_pod\_identity) | terraform-aws-modules/eks-pod-identity/aws | ~> 2.0 |
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | ~>21.0 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | ~>6.0 |

## Resources

| Name | Type |
|------|------|
| [aws_eks_addon.aws-ebs-csi-driver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_eks_pod_identity_association.lb_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_pod_identity_association) | resource |
| [helm_release.alb](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [http_http.management_ip](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_account_id"></a> [aws\_account\_id](#input\_aws\_account\_id) | n/a | `string` | n/a | yes |
| <a name="input_domain"></a> [domain](#input\_domain) | n/a | `string` | n/a | yes |
| <a name="input_eks_cluster_name"></a> [eks\_cluster\_name](#input\_eks\_cluster\_name) | n/a | `string` | `"eks-hcp"` | no |
| <a name="input_eks_k8s_version"></a> [eks\_k8s\_version](#input\_eks\_k8s\_version) | n/a | `string` | `"1.34"` | no |
| <a name="input_eks_managed_node_groups_ssh_key_pair"></a> [eks\_managed\_node\_groups\_ssh\_key\_pair](#input\_eks\_managed\_node\_groups\_ssh\_key\_pair) | n/a | `string` | `null` | no |
| <a name="input_eks_node_capacity_type"></a> [eks\_node\_capacity\_type](#input\_eks\_node\_capacity\_type) | n/a | `string` | `"ON_DEMAND"` | no |
| <a name="input_eks_node_instance_types"></a> [eks\_node\_instance\_types](#input\_eks\_node\_instance\_types) | n/a | `list(string)` | <pre>[<br/>  "t3.medium"<br/>]</pre> | no |
| <a name="input_eks_node_workers"></a> [eks\_node\_workers](#input\_eks\_node\_workers) | Managed nodes group parameters | <pre>object({<br/>    min_size     = number<br/>    max_size     = number<br/>    desired_size = number<br/>    disk_size    = number<br/>  })</pre> | <pre>{<br/>  "desired_size": 3,<br/>  "disk_size": 50,<br/>  "max_size": 6,<br/>  "min_size": 1<br/>}</pre> | no |
| <a name="input_mgmt_cidrs"></a> [mgmt\_cidrs](#input\_mgmt\_cidrs) | n/a | `list(string)` | `[]` | no |
| <a name="input_owner"></a> [owner](#input\_owner) | n/a | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region | `string` | `"eu-west-1"` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | n/a | `string` | `"10.64.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_echoserver_url"></a> [echoserver\_url](#output\_echoserver\_url) | n/a |
| <a name="output_eks_ca_certificate"></a> [eks\_ca\_certificate](#output\_eks\_ca\_certificate) | n/a |
| <a name="output_eks_cluster_endpoint"></a> [eks\_cluster\_endpoint](#output\_eks\_cluster\_endpoint) | EKS cluster EKS endpoint |
| <a name="output_eks_cluster_kube_context"></a> [eks\_cluster\_kube\_context](#output\_eks\_cluster\_kube\_context) | n/a |
| <a name="output_eks_cluster_name"></a> [eks\_cluster\_name](#output\_eks\_cluster\_name) | EKS cluster name |
| <a name="output_eks_cluster_security_group_id_eks_cluster"></a> [eks\_cluster\_security\_group\_id\_eks\_cluster](#output\_eks\_cluster\_security\_group\_id\_eks\_cluster) | EKS cluster control plane SG |
| <a name="output_eks_host"></a> [eks\_host](#output\_eks\_host) | n/a |
| <a name="output_eks_name"></a> [eks\_name](#output\_eks\_name) | n/a |
| <a name="output_eks_node_security_group_id_cluster"></a> [eks\_node\_security\_group\_id\_cluster](#output\_eks\_node\_security\_group\_id\_cluster) | EKS cluster nodes SG |
| <a name="output_region"></a> [region](#output\_region) | AWS region |
| <a name="output_vault_url"></a> [vault\_url](#output\_vault\_url) | n/a |
<!-- END_TF_DOCS -->
