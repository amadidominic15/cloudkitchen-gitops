terraform {
  backend "s3" {
    bucket  = "cloudkitchen-gitops"
    key     = "eks/dns/terraform.tfstate"
    region  = "eu-north-1"
    encrypt = true
  }
}