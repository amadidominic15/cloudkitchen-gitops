terraform {
  backend "s3" {
    bucket  = "cloudkitchen-gitops"
    key     = "eks/production/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}