resource "helm_release" "argocd" {
  name = "argocd"

  repository = "https://argoproj.github.io/argo-helm"

  chart = "argo-cd"

  namespace = "argocd"

  create_namespace = true

  version = var.argocd_chart_version

  wait = true

  timeout = 900

  values = [
    yamlencode({

      global = {
        domain = var.argocd_domain
      }

      configs = {
        params = {
          "server.insecure" = true
        }
      }

      server = {
        replicas = 2

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