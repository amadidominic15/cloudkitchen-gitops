module "vpc" {
  source = "../../modules/vpc"
  environment = var.environment
  private_subnets = var.private_subnets
  public_subnets = var.public_subnets
  vpc_cidr = var.vpc_cidr
  azs = var.azs
}
module "eks" {
  source = "../../modules/eks"
  cluster_name = var.cluster_name
  kubernetes_version = var.kubernetes_version
  environment = var.environment
  vpc_id = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  admin_principal_arn = var.admin_principal_arn
  node_instance_types = var.node_instance_types
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs
  depends_on              = [module.vpc]
}
module "ecr" {
  source = "../../modules/ecr"
  environment = var.environment
  repositories = var.ecr_repositories
}

module "loki_s3" {
  source = "../../modules/loki-s3"
  environment = var.environment
  cluster_name = module.eks.cluster_name
  chunks_bucket = var.loki_chunks_bucket
  ruler_bucket = var.loki_ruler_bucket
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  depends_on = [module.eks]
}
module "eks_blueprint_addons" {
  source = "../../modules/eks_blueprint_addons"
  argocd_chart_version = var.argocd_chart_version
  server_replicas = var.server_replicas
  controller_replicas = var.controller_replicas
  repo_server_replicas = var.repo_server_replicas
  application_set_replicas = var.application_set_replicas
  domain_name = var.domain_name
  blueprint_addons_version = var.blueprint_addons_version
  depends_on = [module.eks]
}

module "envoy_gateway" {
  source = "../../modules/envoy_gateway"
  deployment_replicas = var.deployment_replicas
  aws_region = var.aws_region
  acm_certificate_arn = var.acm_certificate_arn
  depends_on = [ module.eks_blueprint_addons ]
}

