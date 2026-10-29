terraform {
  backend "s3" {
    bucket  = "cloudkitchen-gitops"
    key     = "eks/production/terraform.tfstate"
    region  = "eu-north-1"
    encrypt = true
  }
}