variable "aws_region" {
  type = string
  default = "eu-west-2"
}
variable "environment" {
  type = string
  default = "production"
}
variable "cluster_name" {
  type = string
  default = "production-eks"
}
variable "kubernetes_version" {
  type = string
}
variable "vpc_cidr" {
  type = string
}
variable "private_subnets" {
  type = list(string)
}
variable "public_subnets" {
  type = list(string)
}
variable "azs" {
  type = list(string)
}
variable "domain_name" { 
  type = string 
}
variable "acm_certificate_arn" {
  type = string
  sensitive = true
}
variable "github_repository" { 
  type = string 
}
variable "node_instance_types" {
  type = list(string)
}
variable "endpoint_public_access_cidrs" {
  type = list(string)
}
variable "admin_principal_arn" {
  type = string
}
variable "ecr_repositories" {
  type = set(string)
}
variable "loki_chunks_bucket" { 
  type = string 
}
variable "loki_ruler_bucket" { 
  type = string 
}
variable "argocd_chart_version" {
  type = string
}
variable "server_replicas" {
  type    = number
}
variable "controller_replicas" {
  type    = number
}
variable "repo_server_replicas" {
  type    = number
}
variable "application_set_replicas" {
  type    = number
}
variable "blueprint_addons_version" {
  type = string
}
variable "replica_count" {
  type = number
}