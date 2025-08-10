# Simple CloudFront Distribution Example
# This example demonstrates a basic configuration of the CloudFront module

# Basic CloudFront Distribution without custom domain
module "cloudfront_basic" {
  source = "../"

  project_name               = "my-app"
  environment               = "dev"
  s3_bucket_domain_name     = "my-app-dev-website-abc123.s3.amazonaws.com"
  origin_access_control_id  = "E1234567890123"
  
  tags = {
    Project     = "MyApp"
    Environment = "dev"
  }
}

# CloudFront Distribution with custom domain
module "cloudfront_with_domain" {
  source = "../"

  project_name               = "my-app"
  environment               = "prod"
  s3_bucket_domain_name     = "my-app-prod-website-def456.s3.amazonaws.com"
  origin_access_control_id  = "E9876543210987"
  
  # Custom domain configuration
  domain_name           = "example.com"
  acm_certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
  
  # Enable basic monitoring
  enable_monitoring = true
  
  tags = {
    Project     = "MyApp"
    Environment = "prod"
  }
}

# Outputs
output "basic_distribution_url" {
  description = "Basic CloudFront distribution URL"
  value       = "https://${module.cloudfront_basic.distribution_domain_name}"
}

output "custom_domain_distribution_url" {
  description = "Custom domain CloudFront distribution URL"
  value       = "https://${module.cloudfront_with_domain.domain_name != null ? module.cloudfront_with_domain.domain_name : module.cloudfront_with_domain.distribution_domain_name}"
}