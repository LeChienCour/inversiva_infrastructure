# Complete CloudFront Distribution Example
# This example demonstrates a full production configuration of the CloudFront module

# Data sources for existing resources
data "aws_acm_certificate" "domain_cert" {
  domain   = "example.com"
  statuses = ["ISSUED"]
  
  # ACM certificates for CloudFront must be in us-east-1
  provider = aws.us_east_1
}

data "aws_wafv2_web_acl" "main" {
  name  = "my-web-acl"
  scope = "CLOUDFRONT"
}

data "aws_sns_topic" "alerts" {
  name = "cloudfront-alerts"
}

# S3 bucket for CloudFront logs
resource "aws_s3_bucket" "cloudfront_logs" {
  bucket = "my-app-cloudfront-logs-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_versioning" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

# Production CloudFront Distribution
module "cloudfront_production" {
  source = "../"

  project_name               = "my-nextjs-app"
  environment               = "prod"
  s3_bucket_domain_name     = "my-app-prod-website-abc123.s3.amazonaws.com"
  origin_access_control_id  = "E1234567890123"
  
  # Custom domain configuration
  domain_name           = "app.example.com"
  acm_certificate_arn   = data.aws_acm_certificate.domain_cert.arn
  minimum_tls_version   = "TLSv1.2_2021"
  
  # Security configuration
  content_security_policy = join("; ", [
    "default-src 'self'",
    "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdn.jsdelivr.net",
    "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
    "font-src 'self' https://fonts.gstatic.com",
    "img-src 'self' data: https:",
    "connect-src 'self' https://api.example.com",
    "frame-ancestors 'none'",
    "base-uri 'self'",
    "form-action 'self'"
  ])
  
  web_acl_id = data.aws_wafv2_web_acl.main.arn
  
  # CORS configuration for API integration
  cors_allow_credentials = true
  cors_allow_origins     = ["https://app.example.com", "https://admin.example.com"]
  cors_allow_headers = [
    "Accept",
    "Accept-Language",
    "Authorization",
    "Content-Language",
    "Content-Type",
    "X-Requested-With",
    "X-CSRF-Token"
  ]
  cors_allow_methods = ["GET", "HEAD", "OPTIONS", "POST", "PUT", "PATCH", "DELETE"]
  cors_expose_headers = ["X-Total-Count", "X-Page-Count"]
  cors_max_age_seconds = 86400
  
  # Geographic restrictions (example: allow only specific countries)
  geo_restriction_type      = "whitelist"
  geo_restriction_locations = ["US", "CA", "GB", "DE", "FR", "AU", "JP"]
  
  # Monitoring and alerting
  enable_monitoring         = true
  error_rate_threshold      = 2.0
  origin_latency_threshold  = 2000
  alarm_actions            = [data.aws_sns_topic.alerts.arn]
  
  # Access logging
  logging_bucket           = aws_s3_bucket.cloudfront_logs.id
  logging_include_cookies  = false
  
  # Custom error responses for Next.js SPA routing
  custom_error_responses = [
    {
      error_code            = 404
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 300
    },
    {
      error_code            = 403
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 300
    },
    {
      error_code            = 500
      response_code         = 500
      response_page_path    = "/error.html"
      error_caching_min_ttl = 60
    }
  ]
  
  # Custom headers
  custom_headers = [
    {
      header   = "X-App-Version"
      value    = "1.0.0"
      override = true
    },
    {
      header   = "X-Environment"
      value    = "production"
      override = true
    }
  ]
  
  tags = {
    Project     = "MyNextJSApp"
    Environment = "prod"
    Owner       = "DevOps Team"
    Critical    = "true"
    Backup      = "required"
  }
}

# Development CloudFront Distribution (simplified)
module "cloudfront_development" {
  source = "../"

  project_name               = "my-nextjs-app"
  environment               = "dev"
  s3_bucket_domain_name     = "my-app-dev-website-def456.s3.amazonaws.com"
  origin_access_control_id  = "E9876543210987"
  
  # No custom domain for development
  enable_ipv6 = true
  
  # Relaxed CORS for development
  cors_allow_origins = ["*"]
  cors_allow_headers = ["*"]
  
  # No monitoring for development to save costs
  enable_monitoring = false
  
  # Simplified error responses
  custom_error_responses = [
    {
      error_code            = 404
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 0
    }
  ]
  
  tags = {
    Project     = "MyNextJSApp"
    Environment = "dev"
    Owner       = "DevOps Team"
  }
}

# Outputs
output "production_distribution_id" {
  description = "Production CloudFront distribution ID"
  value       = module.cloudfront_production.distribution_id
}

output "production_distribution_domain" {
  description = "Production CloudFront distribution domain"
  value       = module.cloudfront_production.distribution_domain_name
}

output "development_distribution_id" {
  description = "Development CloudFront distribution ID"
  value       = module.cloudfront_development.distribution_id
}

output "development_distribution_domain" {
  description = "Development CloudFront distribution domain"
  value       = module.cloudfront_development.distribution_domain_name
}

# Example of how to create Route 53 records
resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "app.example.com"
  type    = "A"

  alias {
    name                   = module.cloudfront_production.distribution_domain_name
    zone_id                = module.cloudfront_production.distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

data "aws_route53_zone" "main" {
  name = "example.com"
}