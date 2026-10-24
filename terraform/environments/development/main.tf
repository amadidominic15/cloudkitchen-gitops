module "vpc" {
  source                         = "git::https://github.com/amadidominic15/terraform-modules.git//aws-modules/vpc?ref=main"
  cluster_name                   = var.cluster_name
  environment                    = var.environment
  project                        = var.project
  aws_region                     = var.aws_region
  vpc_cidr                       = var.vpc_cidr
  azs_count                      = var.azs_count
  enable_nat_gateway             = var.enable_nat_gateway
  single_nat_gateway             = var.single_nat_gateway
  enable_vpc_endpoints           = var.enable_vpc_endpoints
  vpc_endpoint_security_group_id = module.security_group.vpc_endpoint_security_group_id
}

module "security_group" {
  source                = "git::https://github.com/amadidominic15/terraform-modules.git//aws-modules/security-group?ref=main"
  cluster_name          = var.cluster_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  vpc_cidr              = var.vpc_cidr
  alb_security_group_id = module.security_group.alb_security_group_id
}

module "eks" {
  source                      = "git::https://github.com/amadidominic15/terraform-modules.git//aws-modules/eks?ref=main"
  cluster_name                = var.cluster_name
  environment                 = var.environment
  kubernetes_version          = var.kubernetes_version
  cluster_public_access_cidrs = var.cluster_public_access_cidrs
  private_subnet_ids          = module.vpc.private_subnets_ids
  cluster_role_arn            = module.iam.eks_cluster_role_arn
  node_role_arn               = module.iam.eks_node_role_arn
  cluster_security_group_id   = module.security_group.cluster_security_group_id
  node_security_group_id      = module.security_group.nodes_security_group_id
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
  node_instance_types = ["t3.medium"]
  node_min_size       = 1
  node_desired_size   = 2
  node_max_size       = 3
}

module "cluster_addons" {
  source                                 = "git::https://github.com/amadidominic15/terraform-modules.git//aws-modules/cluster-addons?ref=main"
  cluster_name                           = var.cluster_name
  aws_region                             = var.aws_region
  vpc_id                                 = module.vpc.vpc_id
  lb_controller_chart_version            = var.lb_controller_chart_version
  argocd_chart_version                   = var.argocd_chart_version
  secrets_store_csi_driver_chart_version = var.secrets_store_csi_driver_chart_version
  deployment_replicas                    = var.deployment_replicas
  acm_certificate_arn                    = var.acm_certificate_arn
  depends_on                             = [module.eks]
}

module "secrets_manager" {
  source  = "git::https://github.com/amadidominic15/terraform-modules.git//aws-modules/secrets-manager?ref=main"
  secrets = var.secrets
}

module "iam" {
  source                          = "git::https://github.com/amadidominic15/terraform-modules.git//aws-modules/iam?ref=main"
  cluster_name                    = var.cluster_name
  enable_vpc_cni                  = true
  enable_ebs_csi                  = true
  enable_cloudwatch               = true
  enable_load_balancer_controller = true
  enable_external_dns             = true
  enable_loki                     = true
  loki_bucket_arn                 = module.s3.loki_bucket_arn
  enable_application_secrets      = true
  application_secret_arns = concat(
    [for name in var.application_secret_names : module.secrets_manager.secret_arns[name]]
  )
}

module "s3" {
  source       = "git::https://github.com/amadidominic15/terraform-modules.git//aws-modules/s3?ref=main"
  cluster_name = var.cluster_name
  environment  = var.environment
  enable_loki  = true
}

module "ecr" {
  source           = "git::https://github.com/amadidominic15/terraform-modules.git//aws-modules/ecr?ref=main"
  ecr_repositories = var.ecr_repositories
}

module "rds" {
  source                  = "git::https://github.com/amadidominic15/terraform-modules.git//aws-modules/rds?ref=main"
  project                 = var.project
  environment             = var.environment
  rds_engine              = var.rds_engine
  rds_engine_version      = var.rds_engine_version
  rds_instance_class      = var.rds_instance_class
  db_name                 = "application"
  master_username         = "dbadmin"
  port                    = 5432
  private_subnet_ids      = module.vpc.private_subnets_ids
  vpc_security_group_ids  = [module.security_group.rds_security_group_id]
  allocated_storage       = 20
  max_allocated_storage   = 100
  multi_az                = true
  backup_retention_period = 7
  deletion_protection     = true
  monitoring_interval     = 0 # Enhanced Monitoring is disabled until an IAM role is provided.
  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}
