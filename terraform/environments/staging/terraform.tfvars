aws_region = "eu-west-2"

project_name = "my-platform"

environment = "staging"

vpc_cidr = "10.10.0.0/16"

azs = [
  "eu-west-2a",
  "eu-west-2b",
  "eu-west-2c"
]

public_subnets = [
  "10.10.101.0/24",
  "10.10.102.0/24",
  "10.10.103.0/24"
]

private_subnets = [
  "10.10.1.0/24",
  "10.10.2.0/24",
  "10.10.3.0/24"
]

kubernetes_version = "1.33"

# IMPORTANT:
# Replace this with your current public IP.
# Do NOT use 0.0.0.0/0 for production.
endpoint_public_access_cidrs = [
  "0.0.0.0/0"
]

# IAM user or role that you use locally with AWS CLI.
admin_principal_arn = "arn:aws:iam::YOUR_ACCOUNT_ID:role/YOUR_ADMIN_ROLE"

node_instance_types = [
  "t3.large"
]

node_min_size = 2

node_max_size = 5

node_desired_size = 2

node_disk_size = 50

ecr_repositories = [
  "frontend",
  "backend",
  "users",
  "orders",
  "payments"
]

argocd_chart_version = "7.9.1"

argocd_domain = "argocd.example.com"

acm_certificate_arn = ""