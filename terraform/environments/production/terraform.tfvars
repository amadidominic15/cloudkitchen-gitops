aws_region = "eu-west-2"

project_name = "my-platform"

environment = "production"

vpc_cidr = "10.20.0.0/16"

azs = [
  "eu-west-2a",
  "eu-west-2b",
  "eu-west-2c"
]

public_subnets = [
  "10.20.101.0/24",
  "10.20.102.0/24",
  "10.20.103.0/24"
]

private_subnets = [
  "10.20.1.0/24",
  "10.20.2.0/24",
  "10.20.3.0/24"
]

kubernetes_version = "1.33"

# ONLY allow your trusted public IP addresses.
endpoint_public_access_cidrs = [
  "YOUR_PUBLIC_IP/32"
]

admin_principal_arn = "arn:aws:iam::YOUR_ACCOUNT_ID:role/YOUR_ADMIN_ROLE"

node_instance_types = [
  "t3.large"
]

node_min_size = 3

node_max_size = 10

node_desired_size = 3

node_disk_size = 80

ecr_repositories = [
  "frontend",
  "backend",
  "users",
  "orders",
  "payments"
]

argocd_chart_version = "7.9.1"

argocd_domain = "argocd.example.com"