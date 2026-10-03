module "eks_blueprint_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = var.blueprint_addons_version
  depends_on = [ module.eks ]
  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_aws_load_balancer_controller = true
  enable_argocd = true
  enable_kube_prometheus_stack = true

  kube_prometheus_stack = {
    chart         = "kube-prometheus-stack"
    chart_version = "77.0.0"
    repository    = "https://prometheus-community.github.io/helm-charts"
    namespace = "monitoring"
    create_namespace = true
    wait          = true
    wait_for_jobs = true
    values = [
      yamlencode({
        grafana = {
          enabled = true
          adminPassword = var.grafana_admin_password
          service = {
            type = "ClusterIP"
          }
          ingress = {
            enabled = false
          }
          "grafana.ini" = {
          server = {
            root_url = "grafana.${var.domain_name}"
          }}
        }

        prometheus = {
          enabled = true
          service = {
            type = "ClusterIP"
          }
          ingress = {
            enabled = false
          }
          prometheusSpec = {
            externalUrl = "prometheus.${var.domain_name}"
            serviceMonitorSelectorNilUsesHelmValues = false
            serviceMonitorSelector = {
              matchLabels = {
                release = "kube-prometheus-stack"
              }
            }
          }
        }

        alertmanager = {
          enabled = true
          service = {
            type = "ClusterIP"
          }
          ingress = {
            enabled = false
          }
          alertmanagerSpec = {
          externalUrl = "alertmanager.${var.domain_name}"
          }
        }
      })
    ]
  }

  argocd = {
    chart         = "argo-cd"
    chart_version = "8.6.3"
    repository    = "https://argoproj.github.io/argo-helm"
    namespace = "argocd"
    create_namespace = true
    wait          = true
    wait_for_jobs = true
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