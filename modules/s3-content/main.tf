# S3 Content Storage Module
# This module creates a private S3 bucket for storing content that will be served via presigned URLs

# Random suffix for unique bucket naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Private S3 bucket for content storage
resource "aws_s3_bucket" "content_bucket" {
  bucket = "${var.bucket_name_prefix}-content-${random_id.bucket_suffix.hex}"

  tags = merge(var.tags, {
    Name        = "${var.bucket_name_prefix}-content-${random_id.bucket_suffix.hex}"
    Environment = var.environment
    Purpose     = "Content Storage"
    Module      = "s3-content"
  })
}

# Block all public access to the bucket
resource "aws_s3_bucket_public_access_block" "content_bucket_pab" {
  bucket = aws_s3_bucket.content_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for the bucket
resource "aws_s3_bucket_versioning" "content_bucket_versioning" {
  bucket = aws_s3_bucket.content_bucket.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# Server-side encryption configuration
resource "aws_s3_bucket_server_side_encryption_configuration" "content_bucket_encryption" {
  bucket = aws_s3_bucket.content_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Lifecycle configuration for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "content_bucket_lifecycle" {
  count  = var.enable_lifecycle_policy ? 1 : 0
  bucket = aws_s3_bucket.content_bucket.id

  rule {
    id     = "content_lifecycle"
    status = "Enabled"

    # Apply to all objects in the bucket
    filter {
      prefix = ""
    }

    # Transition to IA after specified days
    dynamic "transition" {
      for_each = var.lifecycle_transition_ia_days > 0 ? [1] : []
      content {
        days          = var.lifecycle_transition_ia_days
        storage_class = "STANDARD_IA"
      }
    }

    # Transition to Glacier after specified days
    dynamic "transition" {
      for_each = var.lifecycle_transition_glacier_days > 0 ? [1] : []
      content {
        days          = var.lifecycle_transition_glacier_days
        storage_class = "GLACIER"
      }
    }

    # Delete old versions after specified days
    noncurrent_version_expiration {
      noncurrent_days = var.lifecycle_noncurrent_version_expiration_days
    }

    # Delete incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# CORS configuration for web access
resource "aws_s3_bucket_cors_configuration" "content_bucket_cors" {
  bucket = aws_s3_bucket.content_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD", "PUT", "POST"]
    allowed_origins = var.cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}