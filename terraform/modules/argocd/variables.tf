variable "argocd_chart_version" {
  type = string
}

variable "argocd_domain" {
  type    = string
  default = ""
}

variable "server_replicas" {
  type    = number
  default = 2
}

variable "controller_replicas" {
  type    = number
  default = 2
}

variable "repo_server_replicas" {
  type    = number
  default = 2
}

variable "application_set_replicas" {
  type    = number
  default = 2
}