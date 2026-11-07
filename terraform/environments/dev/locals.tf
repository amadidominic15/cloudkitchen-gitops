locals {
  name_prefix = "${var.environment}-${var.project}-${var.aws_region}"

  application_secrets = {
    app = {
      namespace       = "cloudkitchen"
      service_account = "cloudkitchen-sa"
      secret_arns = [
        module.secrets_manager.secret_arns["dev/cloudkitchen/application"]
      ]
      kms_key_arns = [
        module.secrets_manager.kms_key_arns["dev"]
      ]
    }
  }
}