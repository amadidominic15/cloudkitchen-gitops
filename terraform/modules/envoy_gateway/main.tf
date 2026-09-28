resource "helm_release" "envoy_gateway" {
  name = "envoy-gateway"
  repository = "oci://docker.io/envoyproxy"
  chart = "gateway-helm"
  namespace = "envoy-gateway-system"
  create_namespace = true
  version = "1.9.1"
  wait = true
  wait_for_jobs = true
  timeout = 900
  values = [
    yamlencode({
      deployment = {
        replicas = 2
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