variable "cluster_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the EKS Kubernetes API endpoint."

  type = list(string)
}

variable "admin_principal_arn" {
  description = "IAM user or IAM role ARN that should administer the EKS cluster."

  type = string
}

variable "node_instance_types" {
  type = list(string)

  default = [
    "t3.large"
  ]
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 5
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_disk_size" {
  type    = number
  default = 50
}

variable "tags" {
  type    = map(string)
  default = {}
}