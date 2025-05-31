# terraform/variables.tf

# Project Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "cookie-clicker"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# AWS Configuration
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
  default     = "882792563013"
}

# Network Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

#===========================================
# Service Discovery Configuration (追加)
#===========================================

variable "service_discovery_namespace" {
  description = "Service Discovery namespace name"
  type        = string
  default     = "cookie-clicker.local"
}

# ECS Configuration
variable "ecs_cpu" {
  description = "CPU units for ECS tasks"
  type        = number
  default     = 256
}

variable "ecs_memory" {
  description = "Memory (MB) for ECS tasks"
  type        = number
  default     = 512
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 1
}

variable "go_app_port" {
  description = "Port for Go application"
  type        = number
  default     = 8080
}

variable "python_api_port" {
  description = "Port for Python API"
  type        = number
  default     = 8001
}

# DynamoDB Configuration
variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode"
  type        = string
  default     = "PAY_PER_REQUEST"
}

# CloudWatch Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

# GitHub Configuration
variable "github_repo" {
  description = "GitHub repository for OIDC"
  type        = string
  default     = "taxion11/cookie-clicker"
}

# Domain Configuration (Optional)
variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = ""
}

variable "ssl_certificate_arn" {
  description = "SSL certificate ARN for HTTPS"
  type        = string
  default     = ""
}

# Security Configuration
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Feature Flags
variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = false
}

variable "enable_ssl" {
  description = "Enable SSL/HTTPS"
  type        = bool
  default     = false
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring"
  type        = bool
  default     = true
}

# Tags
variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "cookie-clicker"
    Environment = "dev"
    ManagedBy   = "terraform"
    Owner       = "taxion11"
  }
}

# Local Variables
locals {
  # Base naming components
  project_name = var.project_name
  environment  = var.environment
  
  # Common tags
  common_tags = merge(var.common_tags, {
    Environment = var.environment
    Project     = var.project_name
  })
}