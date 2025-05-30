# terraform/vpc.tf

#===========================================
# VPC and Network Resources
#===========================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-vpc-main"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-igw-main"
  })
}

#===========================================
# Subnets
#===========================================

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
  
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-subnet-public-${count.index + 1}"
    Type = "public"
  })
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-subnet-private-${count.index + 1}"
    Type = "private"
  })
}

#===========================================
# NAT Gateway (無効化 - コスト最適化)
#===========================================

# NAT Gateway は削除 - VPCエンドポイントのみでECRアクセス
# コスト削減: $32.85/月 + データ転送料 → $0/月

#===========================================
# Route Tables (修正版)
#===========================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-rt-public"
  })
}

# プライベートサブネット用ルートテーブル (NAT Gateway無しの設定)
resource "aws_route_table" "private" {
  count = length(aws_subnet.private) > 0 ? 1 : 0
  
  vpc_id = aws_vpc.main.id
  
  # NAT Gateway無し - VPCエンドポイント経由でのみ外部アクセス
  # インターネットルートは設定しない (セキュリティ向上)
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-rt-private"
  })
}

#===========================================
# Route Table Associations (修正版)
#===========================================

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# プライベートサブネットを必ず関連付け
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)
  
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

#===========================================
# VPC Endpoints (完全修正版)
#===========================================

# S3 VPC Endpoint (Gateway Type) - 修正版
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  
  # プライベートサブネットのルートテーブルも必ず含める
  route_table_ids = concat(
    [aws_route_table.public.id],
    length(aws_route_table.private) > 0 ? [aws_route_table.private[0].id] : []
  )
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-vpce-s3"
  })
}

# ECR API VPC Endpoint (Interface Type) - 修正版
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  
  private_dns_enabled = true
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-vpce-ecr-api"
  })
}

# ECR DKR VPC Endpoint (Interface Type) - 修正版
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  
  private_dns_enabled = true
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-vpce-ecr-dkr"
  })
}

# CloudWatch Logs VPC Endpoint (ECRプル時のログ出力用) - 追加
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  
  private_dns_enabled = true
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-vpce-logs"
  })
}

#===========================================
# VPC Endpoints Security Group (修正版)
#===========================================

resource "aws_security_group" "vpc_endpoints" {
  name        = "${local.project_name}-${local.environment}-sg-vpce"
  description = "Security group for VPC Endpoints"
  vpc_id      = aws_vpc.main.id
  
  # VPC内からのHTTPS通信を許可
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  
  # ECSタスクからのHTTPS通信を許可
  ingress {
    description     = "HTTPS from ECS Tasks"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
  
  # すべてのアウトバウンド通信を許可
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-sg-vpce"
  })
}