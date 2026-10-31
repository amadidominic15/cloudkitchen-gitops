output "envoy_nlb_dns_name" { value = data.aws_lb.envoy.dns_name }
output "envoy_nlb_zone_id" { value = data.aws_lb.envoy.zone_id }
output "route53_records" { value = values(aws_route53_record.platform)[*].fqdn }
