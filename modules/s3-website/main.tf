# S3 Website Hosting Module
# This module creates an S3 bucket configured for static website hosting
# with CloudFront origin access control and cost optimization features

# Provider requirements are defined in versions.tf

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Generate random suffix for unique bucket naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Local values for naming and configuration
locals {
  bucket_name = "${var.project_name}-${var.environment}-website-${random_id.bucket_suffix.hex}"

  # Environment-specific configurations
  storage_class = var.environment == "prod" ? "STANDARD" : "STANDARD_IA"

  # Lifecycle transition days based on environment
  # AWS requires minimum 30 days for STANDARD_IA transition
  transition_days = var.environment == "prod" ? 30 : 30
  expiration_days = var.environment == "prod" ? 365 : 90

  common_tags = merge(var.tags, {
    Environment = var.environment
    Module      = "s3-website"
    Purpose     = "static-website-hosting"
  })
}

# S3 bucket for website hosting
resource "aws_s3_bucket" "website" {
  bucket = local.bucket_name
  tags   = local.common_tags
}

# S3 bucket versioning configuration
# Note: Object lock requires versioning to be enabled
resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id
  versioning_configuration {
    status = (var.enable_versioning || var.enable_object_lock) ? "Enabled" : "Suspended"
  }
}

# S3 bucket server-side encryption with AES-256
resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 bucket public access block (block all public access)
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket logging configuration for security auditing
resource "aws_s3_bucket_logging" "website" {
  count  = var.access_logging_bucket != null ? 1 : 0
  bucket = aws_s3_bucket.website.id

  target_bucket = var.access_logging_bucket
  target_prefix = "access-logs/${local.bucket_name}/"
}

# S3 bucket request payment configuration (prevent abuse)
resource "aws_s3_bucket_request_payment_configuration" "website" {
  bucket = aws_s3_bucket.website.id
  payer  = "BucketOwner"
}

# S3 bucket object lock configuration (if enabled)
resource "aws_s3_bucket_object_lock_configuration" "website" {
  count  = var.enable_object_lock ? 1 : 0
  bucket = aws_s3_bucket.website.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = var.object_lock_retention_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.website]
}

# S3 bucket intelligent tiering configuration for cost optimization
resource "aws_s3_bucket_intelligent_tiering_configuration" "website" {
  count  = var.enable_intelligent_tiering ? 1 : 0
  bucket = aws_s3_bucket.website.id
  name   = "intelligent-tiering"

  status = "Enabled"

  # Configure tiering for all objects
  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
}

# S3 bucket website configuration
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = var.index_document
  }

  error_document {
    key = var.error_document
  }

  dynamic "routing_rule" {
    for_each = var.routing_rules
    content {
      condition {
        key_prefix_equals = routing_rule.value.condition.key_prefix_equals
      }
      redirect {
        replace_key_prefix_with = routing_rule.value.redirect.replace_key_prefix_with
      }
    }
  }
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "${local.bucket_name}-oac"
  description                       = "Origin Access Control for ${local.bucket_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3 bucket policy for CloudFront origin access control with enhanced security
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = var.cloudfront_distribution_arn
          }
        }
      },
      {
        Sid       = "DenyInsecureConnections"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.website.arn,
          "${aws_s3_bucket.website.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "DenyUnencryptedObjectUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "AES256"
          }
        }
      },
      {
        Sid       = "DenyPublicReadACL"
        Effect    = "Deny"
        Principal = "*"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${aws_s3_bucket.website.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = [
              "public-read",
              "public-read-write",
              "authenticated-read"
            ]
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.website]
}

# S3 bucket lifecycle configuration for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "website" {
  count  = var.enable_lifecycle_policy ? 1 : 0
  bucket = aws_s3_bucket.website.id

  rule {
    id     = "website_lifecycle"
    status = "Enabled"

    # Apply to all objects in the bucket
    filter {}

    # Transition current versions to IA storage class
    transition {
      days          = local.transition_days
      storage_class = "STANDARD_IA"
    }

    # Transition current versions to Glacier
    transition {
      days          = local.transition_days * 2
      storage_class = "GLACIER"
    }

    # Delete old versions after specified days
    noncurrent_version_expiration {
      noncurrent_days = local.expiration_days
    }

    # Delete incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    # Delete expired object delete markers
    expiration {
      expired_object_delete_marker = true
    }
  }

  # Rule for cleaning up old versions if versioning is enabled
  dynamic "rule" {
    for_each = var.enable_versioning ? [1] : []
    content {
      id     = "cleanup_old_versions"
      status = "Enabled"

      # Apply to all objects in the bucket
      filter {}

      noncurrent_version_transition {
        noncurrent_days = local.transition_days
        storage_class   = "STANDARD_IA"
      }

      noncurrent_version_transition {
        noncurrent_days = local.transition_days * 2
        storage_class   = "GLACIER"
      }

      noncurrent_version_expiration {
        noncurrent_days = local.expiration_days
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.website]
}

# S3 bucket notification configuration (optional)
resource "aws_s3_bucket_notification" "website" {
  count  = length(var.notification_configurations) > 0 ? 1 : 0
  bucket = aws_s3_bucket.website.id

  dynamic "lambda_function" {
    for_each = var.notification_configurations
    content {
      lambda_function_arn = lambda_function.value.lambda_function_arn
      events              = lambda_function.value.events
      filter_prefix       = lambda_function.value.filter_prefix
      filter_suffix       = lambda_function.value.filter_suffix
    }
  }
}