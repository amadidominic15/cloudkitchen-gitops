resource "helm_release" "envoy_gateway" {
  name = "envoy-gateway"
  repository = "oci://docker.io/envoyproxy"
  chart = "gateway-helm"
  namespace = "envoy-gateway-system"
  create_namespace = true
  version = var.envoy_gateway_version
  wait = true
  wait_for_jobs = true
  timeout = 900
  depends_on = [ module.eks_blueprint_addons ]
  values = [
    yamlencode({
      deployment = {
        replicas = var.deployment_replicas
        envoyGateway = {
          resources = {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }
      }
    })
  ]
}