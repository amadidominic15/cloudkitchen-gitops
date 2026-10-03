variable "aws_region" {
  type = string
}
variable "acm_certificate_arn" { 
  type = string 
}
variable "envoy_gateway_version" {
  type = string
  default = "1.9.1"
}
variable "deployment_replicas" {
  type    = number
}