# terraform/dynamodb.tf

#===========================================
# DynamoDB Tables
#===========================================

resource "aws_dynamodb_table" "game_data" {
  name           = "${local.project_name}-${local.environment}-dynamodb-gamedata"
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "user_id"
  
  attribute {
    name = "user_id"
    type = "S"
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-dynamodb-gamedata"
  })
}

resource "aws_dynamodb_table" "upgrades" {
  name           = "${local.project_name}-${local.environment}-dynamodb-upgrades"
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "upgrade_id"
  
  attribute {
    name = "upgrade_id"
    type = "S"
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-dynamodb-upgrades"
  })
}

resource "aws_dynamodb_table" "achievements" {
  name           = "${local.project_name}-${local.environment}-dynamodb-achievements"
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "achievement_id"
  
  attribute {
    name = "achievement_id"
    type = "S"
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-dynamodb-achievements"
  })
}