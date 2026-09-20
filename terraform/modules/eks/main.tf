module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.24"

  name               = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  endpoint_public_access  = true
  endpoint_private_access = true

  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  enable_cluster_creator_admin_permissions = true

  authentication_mode = "API_AND_CONFIG_MAP"

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  enable_irsa = true

  addons = {
    coredns = {
      most_recent = true
    }

    kube-proxy = {
      most_recent = true
    }

    vpc-cni = {
      most_recent = true
    }

    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    default = {
      name = "${var.cluster_name}-nodes"

      instance_types = var.node_instance_types

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      capacity_type = "ON_DEMAND"

      disk_size = var.node_disk_size

      ami_type = "AL2023_x86_64_STANDARD"

      subnet_ids = var.private_subnet_ids

      labels = {
        environment = var.environment
      }

      tags = {
        Name = "${var.cluster_name}-nodes"
      }
    }
  }

  access_entries = {
    admin = {
      principal_arn = var.admin_principal_arn

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  tags = var.tags
}