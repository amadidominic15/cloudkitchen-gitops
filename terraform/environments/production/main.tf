module "vpc" {
  source = "../../modules/vpc"
  name = var.environment
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
}
module "ecr" {
  source = "../../modules/ecr"
  environment = var.environment
  repositories = var.ecr_repositories
}
module "aws_lbc" {
  source = "../../modules/aws-lbc"
  cluster_name = module.eks.cluster_name
  region = var.aws_region
  vpc_id = module.vpc.vpc_id
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  depends_on = [module.eks]
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
module "argocd" {
  source = "../../modules/argocd"
  argocd_chart_version = var.argocd_chart_version
  domain_name = var.domain_name
  depends_on = [module.alb_controller, module.loki_s3]
}
module "envoy_gateway" {
  source = "../../modules/envoy-gateway"
  depends_on = [module.argocd, module.aws_lbc]
}
