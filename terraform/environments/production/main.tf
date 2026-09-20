locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name = "${var.project_name}-${var.environment}"

  vpc_cidr = var.vpc_cidr

  azs = var.azs

  public_subnets = var.public_subnets

  private_subnets = var.private_subnets

  single_nat_gateway = false

  tags = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name = "${var.project_name}-${var.environment}-eks"

  environment = var.environment

  kubernetes_version = var.kubernetes_version

  vpc_id = module.vpc.vpc_id

  private_subnet_ids = module.vpc.private_subnet_ids

  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  admin_principal_arn = var.admin_principal_arn

  node_instance_types = var.node_instance_types

  node_min_size = var.node_min_size

  node_max_size = var.node_max_size

  node_desired_size = var.node_desired_size

  node_disk_size = var.node_disk_size

  tags = local.common_tags

  depends_on = [
    module.vpc
  ]
}

module "ecr" {
  source = "../../modules/ecr"

  environment = var.environment

  repositories = var.ecr_repositories

  tags = local.common_tags
}

module "argocd" {
  source = "../../modules/argocd"

  chart_version = var.argocd_chart_version

  domain = var.argocd_domain

  server_replicas = 3

  controller_replicas = 3

  repo_server_replicas = 3

  depends_on = [
    module.eks
  ]
}