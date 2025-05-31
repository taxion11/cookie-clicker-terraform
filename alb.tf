# terraform/alb.tf

#===========================================
# Application Load Balancer
#===========================================

resource "aws_lb" "main" {
  name               = "${local.project_name}-${local.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-alb"
  })
}

#===========================================
# ALB Security Group
#===========================================

resource "aws_security_group" "alb" {
  name        = "${local.project_name}-${local.environment}-sg-alb"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-sg-alb"
  })
}

#===========================================
# Target Groups
#===========================================

# Go Frontend Target Group (ALB用)
resource "aws_lb_target_group" "go_app" {
  name     = "${local.project_name}-${local.environment}-tg-go"
  port     = var.go_app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    path                = "/health"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-tg-go"
  })
}

# 🔥 Python API Target Group削除 (内部専用のため不要)
# resource "aws_lb_target_group" "python_api" {
#   # 削除: Python APIは内部専用でALBに接続しない
# }

#===========================================
# ALB Listeners
#===========================================

# HTTP Listener (Go Frontend専用)
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # デフォルトアクション: Go Frontendにルーティング
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.go_app.arn
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-listener-http"
  })
}

# 🔥 Python API用のListener Rule削除 (内部専用のため不要)
# resource "aws_lb_listener_rule" "python_api" {
#   # 削除: Python APIは内部専用でALBルーティング不要
# }

# HTTPS Listener (オプション - 将来のSSL対応)
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.main.arn
#   port              = "443"
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
#   certificate_arn   = var.certificate_arn  # 変数で定義
#
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.go_app.arn
#   }
#
#   tags = merge(local.common_tags, {
#     Name = "${local.project_name}-${local.environment}-listener-https"
#   })
# }

#===========================================
# Outputs
#===========================================

output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "The canonical hosted zone ID of the load balancer"
  value       = aws_lb.main.zone_id
}

output "alb_arn" {
  description = "The ARN of the load balancer"
  value       = aws_lb.main.arn
}

output "go_app_target_group_arn" {
  description = "ARN of the Go app target group"
  value       = aws_lb_target_group.go_app.arn
}