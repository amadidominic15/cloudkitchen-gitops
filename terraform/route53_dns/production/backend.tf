terraform {
  backend "s3" {
    bucket         = "YOUR_TERRAFORM_STATE_BUCKET"
    key            = "eks-platform/dns/terraform.tfstate"
    region         = "eu-west-2"
    use_lockfile  = true
  }  
}   
