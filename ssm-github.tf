# terraform/github.tf

#===========================================
# GitHub OIDC Provider (既存を参照)
#===========================================

# 既存のGitHub OIDC Providerを参照
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# GitHub Actions Role
resource "aws_iam_role" "github_actions" {
  name = "${local.project_name}-${local.environment}-iam-github-actions"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-iam-github-actions"
  })
}

# GitHub Actions Policy
resource "aws_iam_role_policy" "github_actions" {
  name = "${local.project_name}-${local.environment}-policy-github-actions"
  role = aws_iam_role.github_actions.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:*"
        ]
        Resource = [
          aws_ecr_repository.go_app.arn,
          aws_ecr_repository.python_api.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition"
        ]
        Resource = [
          "arn:aws:ecs:${var.aws_region}:*:task-definition/${local.project_name}-${local.environment}-ecs-task-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService"
        ]
        Resource = [
          "arn:aws:ecs:${var.aws_region}:*:service/${local.project_name}-${local.environment}-ecs-cluster/${local.project_name}-${local.environment}-ecs-service-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeClusters"
        ]
        Resource = [
          "arn:aws:ecs:${var.aws_region}:*:cluster/${local.project_name}-${local.environment}-ecs-cluster"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:ListClusters",
          "ecs:ListServices"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.ecs_task_execution.arn,
          aws_iam_role.ecs_task.arn
        ]
      }
    ]
  })
}