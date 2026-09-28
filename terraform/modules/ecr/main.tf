resource "aws_ecr_repository" "ecr" {
  for_each = var.repositories
  name = "${var.environment}/${each.value}"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
  tags = { 
    Environment = var.environment
    ManagedBy = "Terraform" 
  }
}
resource "aws_ecr_lifecycle_policy" "ecr" {
  for_each = aws_ecr_repository.ecr
  repository = each.value.name
  policy = jsonencode({ 
    rules = [
      { 
        rulePriority = 1
        description = "Keep newest 20 images" 
        selection = { 
          tagStatus = "any"
          countType = "imageCountMoreThan"
          countNumber = 20 
        }
        action = { 
          type = "expire" 
        } 
      }
    ] 
  })
}
