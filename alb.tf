# terraform/alb.tf

#===========================================
# Application Load Balancer
#===========================================

resource "aws_lb" "main" {
  name               = "${local.project_name}-${local.environment}-alb-main"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
  
  enable_deletion_protection = false
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-alb-main"
  })
}

#===========================================
# Target Groups
#===========================================

resource "aws_lb_target_group" "go_app" {
  name        = "${local.project_name}-${local.environment}-tg-go"
  port        = var.go_app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
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

resource "aws_lb_target_group" "python_api" {
  name        = "${local.project_name}-${local.environment}-tg-python"
  port        = var.python_api_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-tg-python"
  })
}

#===========================================
# Listeners
#===========================================

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.go_app.arn
  }
}

resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 100
  
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.python_api.arn
  }
  
  condition {
    path_pattern {
      values = ["/api/*", "/docs", "/redoc", "/openapi.json"]
    }
  }
}

# HTTPS Listener (optional)
resource "aws_lb_listener" "https" {
  count = var.enable_ssl ? 1 : 0
  
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.ssl_certificate_arn
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.go_app.arn
  }
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
    cidr_blocks = var.allowed_cidr_blocks
  }
  
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
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