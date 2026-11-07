module "vpc" {
  source                         = "git::https://github.com/amadidominic15/terraform-modules.git//aws-modules/vpc?ref=main"
  name_prefix                    = local.name_prefix
  project                        = var.project
  environment                    = var.environment
  vpc_cidr                       = var.vpc_cidr
  azs_count                      = var.azs_count
  enable_nat_gateway             = var.enable_nat_gateway
  single_nat_gateway             = var.single_nat_gateway
  enable_vpc_endpoints           = var.enable_vpc_endpoints
  vpc_endpoint_security_group_id = module.security_group.vpc_endpoints_security_group_id
}

module "security_group" {
  source                              = "git::https://github.com/amadidominic15/terraform-modules.git//aws-modules/security-group?ref=main"
  name_prefix                         = local.name_prefix
  vpc_id                              = module.vpc.vpc_id
  create_lb_security_group            = true
  create_eks_security_group           = true
  create_vpc_endpoints_security_group = true
  vpc_endpoints_allow_eks_nodes       = true
  lb_ingress_cidrs                    = ["0.0.0.0/0"]
}

module "eks" {
  source                      = "git::https://github.com/amadidominic15/terraform-modules.git//aws-modules/eks?ref=main"
  name_prefix                 = local.name_prefix
  project                     = var.project
  kubernetes_version          = var.kubernetes_version
  cluster_public_access_cidrs = var.cluster_public_access_cidrs
  private_subnet_ids          = module.vpc.private_subnets_ids
  cluster_role_arn            = module.iam.eks_cluster_role_arn
  node_role_arn               = module.iam.eks_node_role_arn
  karpenter_node_role_arn     = module.iam.karpenter_node_role_arn
  cluster_security_group_id   = module.security_group.eks_cluster_security_group_id
  node_security_group_id      = module.security_group.eks_nodes_security_group_id
  admin_principal_arns        = var.admin_principal_arns
  enable_pod_identity         = true
  pod_identity_role_arns      = module.iam.pod_identity_role_arns
  addons = {
    coredns                         = {}
    kube-proxy                      = {}
    vpc-cni                         = {}
    eks-pod-identity-agent          = {}
    aws-ebs-csi-driver              = {}
    amazon-cloudwatch-observability = {}
    metrics-server                  = {}
  }
  node_instance_types = var.node_instance_types
  node_min_size       = var.node_min_size
  node_desired_size   = var.node_desired_size
  node_max_size       = var.node_max_size
}

module "cluster_addons" {
  source                                 = "git::https://github.com/amadidominic15/terraform-modules.git//aws-modules/cluster-addons?ref=main"
  name_prefix                            = local.name_prefix
  aws_region                             = var.aws_region
  vpc_id                                 = module.vpc.vpc_id
  lb_controller_chart_version            = var.lb_controller_chart_version
  argocd_chart_version                   = var.argocd_chart_version
  replicas                               = var.replicas
  secrets_store_csi_driver_chart_version = var.secrets_store_csi_driver_chart_version
  karpenter_chart_version                = var.karpenter_chart_version
  deployment_replicas                    = var.deployment_replicas
  depends_on                             = [module.eks]
}

module "secrets_manager" {
  source  = "git::https://github.com/amadidominic15/terraform-modules.git//aws-modules/secrets-manager?ref=main"
  secrets = var.secrets
}

module "iam" {
  source                          = "git::https://github.com/amadidominic15/terraform-modules.git//aws-modules/iam?ref=main"
  name_prefix                     = local.name_prefix
  aws_region                      = var.aws_region
  enable_vpc_cni                  = true
  enable_ebs_csi                  = true
  enable_cloudwatch               = true
  enable_load_balancer_controller = true
  enable_external_dns             = true
  enable_loki                     = true
  enable_karpenter                = true
  enable_application_secrets      = true
  tempo_bucket_arn                = module.s3.bucket_arns["tempo"]
  loki_bucket_arn = [
    module.s3.bucket_arns["loki_chunks"], module.s3.bucket_arns["loki_ruler"]
  ]
  application_secrets = local.application_secrets
}

module "s3" {
  source      = "git::https://github.com/amadidominic15/terraform-modules.git//aws-modules/s3?ref=main"
  name_prefix = local.name_prefix
  environment = var.environment
  buckets = {
    loki_chunks = {
      bucket_name        = "${local.name_prefix}-loki-chunks-10-26"
      purpose            = "Loki chunks storage"
      versioning_enabled = true
      enable_encryption  = true
      tags = {
        Name     = "${local.name_prefix}-loki-chunks"
        Workload = "Loki"
      }
    }
    loki_ruler = {
      bucket_name        = "${local.name_prefix}-loki-ruler-10-26"
      purpose            = "Loki ruler storage"
      versioning_enabled = true
      enable_encryption  = true
      tags = {
        Name     = "${local.name_prefix}-loki-ruler"
        Workload = "Loki"
      }
    }
    tempo = {
      bucket_name        = "${local.name_prefix}-tempo-10-26"
      purpose            = "Tempo storage"
      versioning_enabled = true
      enable_encryption  = true
      tags = {
        Name     = "${local.name_prefix}-tempo"
        Workload = "Tempo"
      }
    }
  }
}

module "ecr" {
  source           = "git::https://github.com/amadidominic15/terraform-modules.git//aws-modules/ecr?ref=main"
  project          = var.project
  repository_names = var.repository_names
  force_delete     = true
}


