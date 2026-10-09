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
  description = "Namespace where Argo CD is installed."
  value       = module.addons.namespace
}

output "kubectl_config_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}