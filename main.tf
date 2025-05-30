# terraform/main.tf

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
#   S3 Backend configuration (optional)
   backend "s3" {
     bucket = "terraform-test-nawate"
     key    = "dev/terraform.tfstate"
     region = "ap-northeast-1"
   }
}

# Provider Configuration
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = var.common_tags
  }
}