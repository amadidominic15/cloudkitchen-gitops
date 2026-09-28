data "aws_route53_zone" "main" { 
  name = var.domain_name
  private_zone = false
}
# Workflow 03 confirms this NLB exists before workflow 04 runs.
data "aws_lbs" "envoy" {
  tags = { 
    ManagedBy = "envoy-gateway" 
    Environment = var.environment 
  }
}
locals {
  envoy_lb_arns = tolist(data.aws_lbs.envoy.arns)
  records = {
    argocd = "argocd.${var.domain_name}"
    grafana = "grafana.${var.domain_name}"
    prometheus = "prometheus.${var.domain_name}"
  }
}
# Exactly one public Envoy NLB is expected for this environment.
data "aws_lb" "envoy" { 
  arn = one(local.envoy_lb_arns) 
}
resource "aws_route53_record" "platform" {
  for_each = local.records
  zone_id = data.aws_route53_zone.main.zone_id
  name = each.value
  type = "A"
  alias {
    name = data.aws_lb.envoy.dns_name
    zone_id = data.aws_lb.envoy.zone_id
    evaluate_target_health = true
  }
}
