module "ecr" {
  source           = "git::https://github.com/amadidominic15/terraform-modules.git//aws-modules/ecr?ref=main"
  ecr_repositories = var.ecr_repositories
}
