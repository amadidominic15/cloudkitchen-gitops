module "eks_blueprint_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.24.0"
  cluster_name      = var.cluster_name
  cluster_endpoint  = var.cluster_endpoint
  cluster_version   = var.cluster_version
  oidc_provider_arn = var.oidc_provider_arn
  enable_aws_load_balancer_controller = true
  enable_argocd                        = true

  aws_load_balancer_controller = {
    chart         = "aws-load-balancer-controller"
    chart_version = "1.13.4"
    repository    = "https://aws.github.io/eks-charts"
    namespace     = "kube-system"
    create_namespace = true
    values = [
      yamlencode({
        clusterName = var.cluster_name
        region      = var.aws_region
        vpcId       = var.vpc_id

        replicaCount = var.replica_count
        resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
        }
        serviceAccount = {
          create = true
          name   = "aws-load-balancer-controller"
        }
      })
    ]
  }

  argocd = {
    chart         = "argo-cd"
    chart_version = "8.6.3"
    repository    = "https://argoproj.github.io/argo-helm"
    namespace     = "argocd"
    create_namespace = true

    values = [
      yamlencode({
        crds = {
          keep = false
        }

        global = {
          domain = "argocd.${var.domain_name}"
        }
        configs = {
          params = {
            "server.insecure" = true
          }
        }
        server = {
          replicas = var.server_replicas
          service = {
            type = "ClusterIP"
          }
          ingress = {
            enabled = false
          }
          httproute = {
            enabled = false
          }
        }
        controller = {
          replicas = var.controller_replicas
        }
        repoServer = {
          replicas = var.repo_server_replicas
        }
        applicationSet = {
          replicas = var.application_set_replicas
        }
      })
    ]
  }
  tags = {
    "kubernetes.io/cluster/${var.environment}-eks" = "shared"
  }
}