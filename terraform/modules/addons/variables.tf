variable "aws_region" {
  type = string
}
variable "environment" {
  type = string
}
variable "domain_name" {
  type    = string
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
variable "replica_count" {
  type    = number
}
variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}
variable "cluster_endpoint" {
  description = "Endpoint of the EKS cluster."
  type        = string
}
variable "cluster_version" {
  description = "Kubernetes version of the EKS cluster."
  type        = string
}
variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider."
  type        = string
}
variable "vpc_id" {
  description = "ID of the VPC hosting the EKS cluster."
  type        = string
}