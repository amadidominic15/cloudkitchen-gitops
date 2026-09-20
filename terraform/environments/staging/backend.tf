terraform {
  backend "s3" {
    bucket = "REPLACE_WITH_YOUR_TERRAFORM_STATE_BUCKET"

    key = "eks/staging/terraform.tfstate"

    region = "eu-west-2"

    encrypt = true
  }
}