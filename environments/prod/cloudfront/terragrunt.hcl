# CloudFront Module Configuration for Production Environment

# Include the root terragrunt configuration
include "root" {
  path = find_in_parent_folders()
}

# Include the environment configuration
include "env" {
  path = find_in_parent_folders("terragrunt.hcl")
}

# Configure the terraform source
terraform {
  source = "../../../modules/cloudfront"
}

# Dependencies - CloudFront depends on Route53/ACM for certificate and S3 website
dependencies {
  paths = ["../route53-acm", "../s3-website"]
}

dependency "route53_acm" {
  config_path = "../route53-acm"
  
  mock_outputs = {
    certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/example-123"
  }
  
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "s3_website" {
  config_path = "../s3-website"
  
  mock_outputs = {
    bucket_domain_name = "inversiva-prod-website.s3.amazonaws.com"
    bucket_regional_domain_name = "inversiva-prod-website.s3.us-east-1.amazonaws.com"
  }
  
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# Module-specific inputs - all configuration comes from environment
inputs = {
  # S3 origin configuration from dependency
  s3_bucket_domain_name = dependency.s3_website.outputs.bucket_regional_domain_name
  origin_access_control_id = null  # Will be created by CloudFront module
  use_s3_website_endpoint = false
  
  # Domain and certificate configuration from environment
  domain_name = local.domain_name
  acm_certificate_arn = dependency.route53_acm.outputs.certificate_arn
  minimum_tls_version = local.prod_config.cloudfront.minimum_tls_version
  
  # All CloudFront configuration from environment
  price_class = local.prod_config.cloudfront.price_class
  enable_ipv6 = local.prod_config.cloudfront.enable_ipv6
  enable_monitoring = local.prod_config.cloudfront.enable_monitoring
  
  # CloudFront configuration
  default_root_object = "index.html"
  
  # Geographic restrictions from environment
  geo_restriction_type = local.prod_config.cloudfront.geo_restriction_type
  geo_restriction_locations = local.prod_config.cloudfront.geo_restriction_locations
  
  # Security headers from environment
  content_security_policy = local.prod_config.cloudfront.content_security_policy
  
  # Custom headers (production security headers)
  custom_headers = [
    {
      name  = "Strict-Transport-Security"
      value = "max-age=31536000; includeSubDomains; preload"
    },
    {
      name  = "X-Content-Type-Options"
      value = "nosniff"
    },
    {
      name  = "X-Frame-Options"
      value = "DENY"
    },
    {
      name  = "X-XSS-Protection"
      value = "1; mode=block"
    },
    {
      name  = "Referrer-Policy"
      value = "strict-origin-when-cross-origin"
    }
  ]
  
  # CORS configuration from environment
  cors_allow_credentials = local.prod_config.cors.allow_credentials
  cors_allow_headers = local.prod_config.cors.allow_headers
  cors_allow_methods = local.prod_config.cors.allow_methods
  cors_allow_origins = local.prod_config.cors.allow_origins
  cors_expose_headers = local.prod_config.cors.expose_headers
  cors_max_age_seconds = local.prod_config.cors.max_age_seconds
  
  # Error handling from environment
  custom_error_responses = local.prod_config.cloudfront.custom_error_responses
  
  # Logging configuration from environment
  logging_bucket = local.prod_config.cloudfront.logging_bucket
  logging_include_cookies = local.prod_config.cloudfront.logging_include_cookies
  
  # Production cache behavior
  default_cache_behavior = local.prod_config.cloudfront.default_cache_behavior
  
  # WAF integration (if needed)
  web_acl_id = local.prod_config.cloudfront.web_acl_id
  
  # Monitoring configuration (disabled for cost optimization)
  error_rate_threshold = 10.0  # Higher threshold to reduce false alarms
  origin_latency_threshold = 10000  # Higher threshold for cost optimization
  alarm_actions = []  # No alarm actions to save costs
}