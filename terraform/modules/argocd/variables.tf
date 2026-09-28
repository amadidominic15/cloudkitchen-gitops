variable "argocd_chart_version" {
  type = string
}
variable "domain_name" {
  type    = string
}
variable "server_replicas" {
  type    = number
}
variable "controller_replicas" {
  type    = number
}
variable "repo_server_replicas" {
  type    = number
}
variable "application_set_replicas" {
  type    = number
}