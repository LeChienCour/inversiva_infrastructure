# Basic Monitoring Example
# This example shows the minimal configuration for monitoring

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Example S3 buckets (normally these would be from other modules)
resource "aws_s3_bucket" "website" {
  bucket = "example-website-bucket-${random_id.suffix.hex}"
}

resource "aws_s3_bucket" "content" {
  bucket = "example-content-bucket-${random_id.suffix.hex}"
}

resource "random_id" "suffix" {
  byte_length = 4
}

# Example CloudFront distribution (normally this would be from another module)
resource "aws_cloudfront_distribution" "example" {
  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.website.bucket}"

    s3_origin_config {
      origin_access_identity = ""
    }
  }

  enabled = true

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.website.bucket}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Basic monitoring configuration
module "monitoring" {
  source = "../"

  project_name               = "example-app"
  environment               = "dev"
  cloudfront_distribution_id = aws_cloudfront_distribution.example.id
  website_bucket_name       = aws_s3_bucket.website.bucket
  website_bucket_arn        = aws_s3_bucket.website.arn
  content_bucket_name       = aws_s3_bucket.content.bucket
  content_bucket_arn        = aws_s3_bucket.content.arn

  # Basic configuration
  alert_email_addresses = ["admin@example.com"]
  monthly_budget_limit  = "50"
  enable_cloudtrail     = false
  log_retention_days    = 7
}

# Outputs
output "dashboard_url" {
  description = "URL to access the CloudWatch dashboard"
  value       = module.monitoring.dashboard_url
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = module.monitoring.sns_topic_arn
}