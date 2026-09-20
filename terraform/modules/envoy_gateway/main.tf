resource "helm_release" "envoy_gateway" {
  name = "envoy-gateway"

  repository = "oci://docker.io/envoyproxy"

  chart = "gateway-helm"

  namespace = "envoy-gateway-system"

  create_namespace = true

  version = "1.9.1"

  wait = true

  timeout = 900

  values = [
    yamlencode({
      deployment = {
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