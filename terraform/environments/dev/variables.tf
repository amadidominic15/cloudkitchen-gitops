variable "aws_region" {}
variable "azs_count" {}
variable "environment" {}
variable "project" {}
variable "vpc_cidr" {}
variable "enable_nat_gateway" {}
variable "single_nat_gateway" {}
variable "enable_vpc_endpoints" {}
variable "kubernetes_version" {}
variable "cluster_public_access_cidrs" {}
variable "admin_principal_arns" {}
variable "repository_names" {}
variable "lb_controller_chart_version" {}
variable "argocd_chart_version" {}
variable "acm_certificate_arn" {}
variable "envoy_gateway_version" {}
variable "deployment_replicas" {}
variable "secrets_store_csi_driver_chart_version" {}
variable "secrets" {}
variable "application_secret_names" {
  description = "Secret names this application's IAM role is allowed to read."
  type        = list(string)
}