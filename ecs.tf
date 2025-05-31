# terraform/ecs.tf

#===========================================
# Service Discovery (追加)
#===========================================

# Service Discovery Namespace
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${local.project_name}.local"
  description = "Service discovery namespace for ${local.project_name}"
  vpc         = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-service-discovery"
  })
}

# Python API Service Discovery Service
resource "aws_service_discovery_service" "python_api" {
  name = "python-api"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 60
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-service-discovery-python"
  })
}

#===========================================
# ECS Cluster
#===========================================

resource "aws_ecs_cluster" "main" {
  name = "${local.project_name}-${local.environment}-ecs-cluster"
  
  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      
      log_configuration {
        cloud_watch_encryption_enabled = false
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.go_app.name
      }
    }
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-ecs-cluster"
  })
}

#===========================================
# CloudWatch Log Groups
#===========================================

resource "aws_cloudwatch_log_group" "go_app" {
  name              = "/aws/ecs/${local.project_name}-${local.environment}-logs-go"
  retention_in_days = var.log_retention_days
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-logs-go"
  })
}

resource "aws_cloudwatch_log_group" "python_api" {
  name              = "/aws/ecs/${local.project_name}-${local.environment}-logs-python"
  retention_in_days = var.log_retention_days
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-logs-python"
  })
}

#===========================================
# IAM Roles
#===========================================

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.project_name}-${local.environment}-iam-ecs-execution"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-iam-ecs-execution"
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Role
resource "aws_iam_role" "ecs_task" {
  name = "${local.project_name}-${local.environment}-iam-ecs-task"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-iam-ecs-task"
  })
}

# DynamoDB access policy for ECS tasks
resource "aws_iam_role_policy" "ecs_task_dynamodb" {
  name = "${local.project_name}-${local.environment}-policy-ecs-dynamodb"
  role = aws_iam_role.ecs_task.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.game_data.arn,
          aws_dynamodb_table.upgrades.arn,
          aws_dynamodb_table.achievements.arn
        ]
      }
    ]
  })
}

#===========================================
# ECS Security Group (修正)
#===========================================

resource "aws_security_group" "ecs" {
  name        = "${local.project_name}-${local.environment}-sg-ecs"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id
  
  # Go App - ALBからのアクセス
  ingress {
    description     = "Go App Port from ALB"
    from_port       = var.go_app_port
    to_port         = var.go_app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  
  # Python API - ECS内部通信のみ (ALBアクセス削除)
  ingress {
    description = "Python API Port from ECS internal"
    from_port   = var.python_api_port
    to_port     = var.python_api_port
    protocol    = "tcp"
    self        = true  # 同じセキュリティグループ内での通信のみ許可
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-sg-ecs"
  })
}

#===========================================
# ECS Task Definitions (修正)
#===========================================

resource "aws_ecs_task_definition" "go_app" {
  family                   = "${local.project_name}-${local.environment}-ecs-task-go"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn           = aws_iam_role.ecs_task.arn
  
  container_definitions = jsonencode([
    {
      name  = "cookie-clicker-go"
      image = "${aws_ecr_repository.go_app.repository_url}:latest"
      
      portMappings = [
        {
          containerPort = var.go_app_port
          protocol      = "tcp"
        }
      ]
      
      essential = true
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.go_app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      environment = [
        {
          name  = "PORT"
          value = tostring(var.go_app_port)
        },
        {
          name  = "ENV"
          value = var.environment
        },
        {
          name  = "GIN_MODE"
          value = "release"
        },
        # 🔥 Service Discovery URL追加
        {
          name  = "PYTHON_API_URL"
          value = "http://python-api.${local.project_name}.local:${var.python_api_port}"
        }
      ]
      
      # ヘルスチェック設定を大幅に緩和
      healthCheck = {
        command = [
          "CMD-SHELL",
          "wget --quiet --tries=1 --spider http://localhost:${var.go_app_port}/health || exit 1"
        ]
        interval    = 60      # 30秒 → 60秒に延長
        timeout     = 15      # 5秒 → 15秒に延長  
        retries     = 5       # 3回 → 5回に増加
        startPeriod = 300     # 60秒 → 300秒（5分）に延長
      }
    }
  ])

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-ecs-task-go"
  })
}

resource "aws_ecs_task_definition" "python_api" {
  family                   = "${local.project_name}-${local.environment}-ecs-task-python"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn           = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "cookie-clicker-python"
      image = "${aws_ecr_repository.python_api.repository_url}:latest"
      
      portMappings = [
        {
          containerPort = var.python_api_port
          protocol      = "tcp"
        }
      ]
      
      essential = true
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.python_api.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      environment = [
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        },
        {
          name  = "ENVIRONMENT"
          value = var.environment
        },
        {
          name  = "LOG_LEVEL"
          value = "INFO"
        },
        {
          name  = "HOST"
          value = "0.0.0.0"
        },
        {
          name  = "PORT"
          value = tostring(var.python_api_port)
        }
      ]
      
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:${var.python_api_port}/health || exit 1"
        ]
        interval    = 60      # 30秒 → 60秒に延長
        timeout     = 15      # 5秒 → 15秒に延長  
        retries     = 5       # 3回 → 5回に増加
        startPeriod = 300     # 60秒 → 300秒（5分）に延長
      }
    }
  ])

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-ecs-task-python"
  })
}

#===========================================
# ECS Services (修正)
#===========================================

# Go Frontend Service (ALB接続)
resource "aws_ecs_service" "go_app" {
  name            = "${local.project_name}-${local.environment}-ecs-service-go"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.go_app.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"
  health_check_grace_period_seconds = 300  # 5分の猶予

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.go_app.arn
    container_name   = "cookie-clicker-go"
    container_port   = var.go_app_port
  }

  depends_on = [
    aws_lb_listener.main,
    aws_iam_role_policy.ecs_task_dynamodb,
    aws_ecs_task_definition.go_app
  ]

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-ecs-service-go"
  })
}

# Python API Service (内部専用、Service Discovery付き)
resource "aws_ecs_service" "python_api" {
  name            = "${local.project_name}-${local.environment}-ecs-service-python"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.python_api.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"
  health_check_grace_period_seconds = 300  # 5分の猶予

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false  # パブリックIP不要（内部専用）
  }

  # 🔥 Service Discovery 登録追加
  service_registries {
    registry_arn = aws_service_discovery_service.python_api.arn
  }

  # 🔥 ALB Target Group削除（内部専用のため）
  # load_balancer ブロックを削除

  depends_on = [
    aws_iam_role_policy.ecs_task_dynamodb,
    aws_ecs_task_definition.python_api,
    aws_service_discovery_service.python_api
  ]

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-ecs-service-python"
  })
}
