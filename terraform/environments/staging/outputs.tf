
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_arn" {
  value = module.eks.cluster_arn
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "argocd_namespace" {
  value = module.argocd.namespace
}

output "argocd_release" {
  value = module.argocd.release_name
}

output "aws_load_balancer_controller_role" {
  value = module.aws_load_balancer_controller.role_arn
}