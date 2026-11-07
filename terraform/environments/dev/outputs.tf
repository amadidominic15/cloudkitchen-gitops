output "lb_security_group_id" {
  description = "Load Balancer security group ID"
  value       = module.security_group.lb_security_group_id
}