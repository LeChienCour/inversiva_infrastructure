# Bootstrap infrastructure for Terraform state management
# This creates the S3 bucket and DynamoDB table required for remote state

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = var.common_tags
  }
}

# Generate random suffix for unique resource naming
resource "random_id" "suffix" {
  byte_length = 4
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Local values for resource naming
locals {
  aws_account_id      = data.aws_caller_identity.current.account_id
  state_bucket_name   = "${var.project_name}-tfstate-${local.aws_account_id}-${var.aws_region}"
  dynamodb_table_name = "${var.project_name}-tfstate-lock"
}

# S3 bucket for storing Terraform state files
resource "aws_s3_bucket" "terraform_state" {
  bucket = local.state_bucket_name
  
  tags = merge(var.common_tags, {
    Name        = local.state_bucket_name
    Purpose     = "terraform-state-storage"
    Description = "S3 bucket for storing Terraform state files"
  })
}

# Enable versioning on the S3 bucket for state file recovery
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption for the S3 bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block public access to the S3 bucket
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = local.dynamodb_table_name
  billing_mode   = "PAY_PER_REQUEST"  # Cost-effective for infrequent access
  hash_key       = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
  
  tags = merge(var.common_tags, {
    Name        = local.dynamodb_table_name
    Purpose     = "terraform-state-locking"
    Description = "DynamoDB table for Terraform state locking"
  })
}

# Lifecycle policy for the S3 bucket to optimize costs
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  rule {
    id     = "terraform_state_lifecycle"
    status = "Enabled"
    
    # Move old versions to cheaper storage classes
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }
    
    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }
    
    # Delete very old versions to control costs
    noncurrent_version_expiration {
      noncurrent_days = 365
    }
    
    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}