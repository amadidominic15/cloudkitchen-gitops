output "role_arn" {
  value = aws_iam_role.aws_load_balancer_controller.arn
}

output "release_name" {
  value = helm_release.aws_load_balancer_controller.name
}