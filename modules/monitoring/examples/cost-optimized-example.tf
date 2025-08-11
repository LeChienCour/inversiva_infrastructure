# Ultra Cost-Optimized Monitoring Example
# This example shows minimal monitoring configuration for maximum cost savings

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
  bucket = "cost-optimized-website-${random_id.suffix.hex}"
}

resource "aws_s3_bucket" "content" {
  bucket = "cost-optimized-content-${random_id.suffix.hex}"
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
    allowed_methods        = ["GET", "HEAD"]
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

# Ultra cost-optimized monitoring configuration
module "monitoring" {
  source = "../"

  project_name               = "cost-optimized-app"
  environment               = "dev"
  cloudfront_distribution_id = aws_cloudfront_distribution.example.id
  website_bucket_name       = aws_s3_bucket.website.bucket
  website_bucket_arn        = aws_s3_bucket.website.arn
  content_bucket_name       = aws_s3_bucket.content.bucket
  content_bucket_arn        = aws_s3_bucket.content.arn

  # Ultra-low cost configuration
  alert_email_addresses      = ["admin@example.com"]
  monthly_budget_limit       = "5"     # Very low budget
  enable_cloudtrail         = false    # Disabled to save costs
  log_retention_days        = 1        # Minimum retention
  enable_detailed_monitoring = false   # Disabled
  enable_dashboard          = false    # Disabled to save ~$3/month
  enable_performance_alarms = false    # Only cost alarms
  enable_cost_alarms        = true     # Keep cost monitoring
  enable_sns_alerts         = true     # Keep cost alerts
  cost_alarm_threshold      = "1"      # Alert if daily cost > $1
}

# Outputs
output "monitoring_cost_estimate" {
  description = "Estimated monthly monitoring costs"
  value = {
    sns_topic           = "Free (first 1,000 email notifications/month)"
    budget              = "Free (first 2 budgets per account)"
    cost_alarm          = "~$0.10/month (1 alarm)"
    cloudwatch_logs     = "~$0.50/month (minimal logs with 1-day retention)"
    total_estimated     = "~$0.60/month"
    dashboard_savings   = "Saved ~$3.00/month by disabling dashboard"
    cloudtrail_savings  = "Saved ~$2.00/month by disabling CloudTrail"
    alarm_savings       = "Saved ~$0.20/month by reducing alarms"
  }
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for cost alerts"
  value       = module.monitoring.sns_topic_arn
}

output "budget_name" {
  description = "Name of the cost budget"
  value       = module.monitoring.budget_name
}

output "enabled_features" {
  description = "List of enabled monitoring features"
  value = {
    dashboard          = false
    cloudtrail        = false
    performance_alarms = false
    cost_alarms       = true
    sns_alerts        = true
    detailed_monitoring = false
  }
}