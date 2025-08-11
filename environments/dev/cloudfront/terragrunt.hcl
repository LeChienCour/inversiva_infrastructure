# CloudFront Module Configuration for Development Environment

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

# Dependencies - CloudFront depends on Route53/ACM for certificate
dependencies {
  paths = ["../route53-acm"]
}

dependency "route53_acm" {
  config_path = "../route53-acm"
  
  mock_outputs = {
    certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/example-123"
  }
  
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# Module-specific inputs - all configuration comes from environment
inputs = {
  # S3 origin configuration (will be provided by S3 website module)
  s3_bucket_domain_name = "inversiva-dev-website.s3.amazonaws.com"  # Placeholder, will be updated by S3 module
  origin_access_control_id = null  # Will be created by CloudFront module
  use_s3_website_endpoint = false
  
  # Domain and certificate configuration from environment
  domain_name = local.domain_name
  acm_certificate_arn = dependency.route53_acm.outputs.certificate_arn
  minimum_tls_version = local.dev_config.cloudfront.minimum_tls_version
  
  # All CloudFront configuration from environment
  price_class = local.dev_config.cloudfront.price_class
  enable_ipv6 = local.dev_config.cloudfront.enable_ipv6
  enable_monitoring = local.dev_config.cloudfront.enable_monitoring
  
  # CloudFront configuration
  default_root_object = "index.html"
  
  # Geographic restrictions (none for dev)
  geo_restriction_type = "none"
  geo_restriction_locations = []
  
  # Security headers from environment
  content_security_policy = local.dev_config.cloudfront.content_security_policy
  
  # Custom headers (minimal for dev)
  custom_headers = []
  
  # CORS configuration from environment
  cors_allow_credentials = local.dev_config.cors.allow_credentials
  cors_allow_headers = local.dev_config.cors.allow_headers
  cors_allow_methods = local.dev_config.cors.allow_methods
  cors_allow_origins = local.dev_config.cors.allow_origins
  cors_expose_headers = local.dev_config.cors.expose_headers
  cors_max_age_seconds = local.dev_config.cors.max_age_seconds
  
  # Error handling from environment
  custom_error_responses = local.dev_config.cloudfront.custom_error_responses
  
  # Logging configuration from environment
  logging_bucket = local.dev_config.cloudfront.logging_bucket
  logging_include_cookies = local.dev_config.cloudfront.logging_include_cookies
  
  # Monitoring configuration (disabled for cost savings)
  error_rate_threshold = 10.0  # Higher threshold for dev
  origin_latency_threshold = 10000  # Higher threshold for dev
  alarm_actions = []
}