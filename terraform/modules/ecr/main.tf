module "ecr" {
  for_each = toset(var.repositories)

  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 3.0"

  repository_name = "${var.environment}/${each.value}"

  repository_type = "private"

  repository_image_tag_mutability = "IMMUTABLE"

  repository_image_scan_on_push = true

  repository_encryption_type = "AES256"

  repository_force_delete = false

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1

        description = "Keep last 30 tagged images"

        selection = {
          tagStatus   = "tagged"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }

        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2

        description = "Remove untagged images"

        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }

        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = var.tags
}