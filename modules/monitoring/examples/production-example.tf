# Production Monitoring Example
# This example shows comprehensive monitoring configuration for production

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

# Example resources (normally these would be from other modules)
resource "aws_s3_bucket" "website" {
  bucket = "prod-website-bucket-${random_id.suffix.hex}"
}

resource "aws_s3_bucket" "content" {
  bucket = "prod-content-bucket-${random_id.suffix.hex}"
}

resource "random_id" "suffix" {
  byte_length = 4
}

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

# Cognito User Pool example
resource "aws_cognito_user_pool" "example" {
  name = "prod-user-pool"
}

# Production monitoring configuration with full features
module "monitoring" {
  source = "../"

  project_name               = "production-app"
  environment               = "prod"
  cloudfront_distribution_id = aws_cloudfront_distribution.example.id
  website_bucket_name       = aws_s3_bucket.website.bucket
  website_bucket_arn        = aws_s3_bucket.website.arn
  content_bucket_name       = aws_s3_bucket.content.bucket
  content_bucket_arn        = aws_s3_bucket.content.arn
  cognito_user_pool_id      = aws_cognito_user_pool.example.id

  # Production configuration with comprehensive monitoring
  alert_email_addresses      = ["ops@example.com", "admin@example.com", "security@example.com"]
  monthly_budget_limit       = "500"
  enable_cloudtrail         = true
  log_retention_days        = 90
  enable_detailed_monitoring = true
}

# Additional CloudWatch alarms for production
resource "aws_cloudwatch_metric_alarm" "high_cost_alarm" {
  alarm_name          = "production-app-high-cost"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"
  statistic           = "Maximum"
  threshold           = "400"
  alarm_description   = "This metric monitors estimated charges"
  alarm_actions       = [module.monitoring.sns_topic_arn]

  dimensions = {
    Currency = "USD"
  }
}

# Custom metric for application-specific monitoring
resource "aws_cloudwatch_log_metric_filter" "application_errors" {
  name           = "production-app-application-errors"
  log_group_name = "/aws/lambda/production-app"
  pattern        = "[timestamp, request_id, ERROR]"

  metric_transformation {
    name      = "ApplicationErrors"
    namespace = "ProductionApp/Application"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "application_error_alarm" {
  alarm_name          = "production-app-application-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApplicationErrors"
  namespace           = "ProductionApp/Application"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors application errors"
  alarm_actions       = [module.monitoring.sns_topic_arn]
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

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = module.monitoring.cloudtrail_arn
}

output "budget_name" {
  description = "Name of the cost budget"
  value       = module.monitoring.budget_name
}

output "alarm_names" {
  description = "List of all alarm names"
  value       = concat(module.monitoring.alarm_names, [
    aws_cloudwatch_metric_alarm.high_cost_alarm.alarm_name,
    aws_cloudwatch_metric_alarm.application_error_alarm.alarm_name
  ])
}