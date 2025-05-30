# terraform/ecr.tf

#===========================================
# ECR Repositories
#===========================================

resource "aws_ecr_repository" "go_app" {
  name                 = "${local.project_name}-${local.environment}-ecr-go"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-ecr-go"
  })
}

resource "aws_ecr_repository" "python_api" {
  name                 = "${local.project_name}-${local.environment}-ecr-python"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-ecr-python"
  })
}

#===========================================
# ECR Lifecycle Policies
#===========================================

resource "aws_ecr_lifecycle_policy" "go_app" {
  repository = aws_ecr_repository.go_app.name
  
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "python_api" {
  repository = aws_ecr_repository.python_api.name
  
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}