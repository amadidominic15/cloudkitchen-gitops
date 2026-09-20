variable "aws_region" {
  type = string
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "kubernetes_version" {
  type = string
}

variable "endpoint_public_access_cidrs" {
  type = list(string)
}

variable "admin_principal_arn" {
  type = string
}

variable "node_instance_types" {
  type = list(string)
}

variable "node_min_size" {
  type = number
}

variable "node_max_size" {
  type = number
}

variable "node_desired_size" {
  type = number
}

variable "node_disk_size" {
  type = number
}

variable "ecr_repositories" {
  type = list(string)
}

variable "argocd_chart_version" {
  type = string
}

variable "argocd_domain" {
  type = string
}