# Cost-Optimized CloudFront Distribution Example
# This example demonstrates the most cost-effective configuration

# Ultra cost-optimized development environment
module "cloudfront_cost_optimized_dev" {
  source = "../"

  project_name               = "my-app"
  environment               = "dev"
  s3_bucket_domain_name     = "my-app-dev-website-abc123.s3.amazonaws.com"
  origin_access_control_id  = "E1234567890123"
  
  # Cost optimization settings
  price_class     = "PriceClass_100"  # Most cost-effective (US, Canada, Europe only)
  enable_ipv6     = false             # Disable IPv6 to save costs
  enable_monitoring = false           # No monitoring for dev to save costs
  
  # No custom domain to avoid certificate costs
  # No logging to avoid S3 storage costs
  
  # Minimal CORS for development
  cors_allow_origins = ["*"]
  
  # Simplified error responses (no custom error pages)
  custom_error_responses = []
  
  tags = {
    Project     = "MyApp"
    Environment = "dev"
    CostCenter  = "development"
  }
}

# Cost-optimized production environment
module "cloudfront_cost_optimized_prod" {
  source = "../"

  project_name               = "my-app"
  environment               = "prod"
  s3_bucket_domain_name     = "my-app-prod-website-def456.s3.amazonaws.com"
  origin_access_control_id  = "E9876543210987"
  
  # Balanced cost/performance for production
  price_class     = "PriceClass_200"  # Good balance (excludes expensive regions)
  enable_ipv6     = false             # Disable if not needed globally
  enable_monitoring = true            # Enable only for production
  
  # Custom domain only if business requires it
  domain_name           = "app.example.com"
  acm_certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
  
  # Restrictive CORS to avoid unnecessary traffic
  cors_allow_origins = ["https://app.example.com"]
  cors_allow_methods = ["GET", "HEAD", "OPTIONS"]  # Minimal methods
  
  # Geographic restrictions to reduce global traffic costs
  geo_restriction_type      = "whitelist"
  geo_restriction_locations = ["US", "CA", "GB"]  # Only serve to necessary regions
  
  # Minimal monitoring thresholds to avoid false alarms
  error_rate_threshold      = 10.0  # Higher threshold
  origin_latency_threshold  = 10000 # Higher threshold
  
  # No access logging to save S3 costs (enable only if compliance requires)
  # logging_bucket = null
  
  tags = {
    Project     = "MyApp"
    Environment = "prod"
    CostCenter  = "production"
    Critical    = "true"
  }
}

# Cost comparison outputs
output "cost_optimization_summary" {
  description = "Summary of cost optimization features enabled"
  value = {
    dev_environment = {
      price_class       = module.cloudfront_cost_optimized_dev.price_class
      ipv6_enabled      = module.cloudfront_cost_optimized_dev.ipv6_enabled
      monitoring_enabled = module.cloudfront_cost_optimized_dev.monitoring_enabled
      custom_domain     = module.cloudfront_cost_optimized_dev.custom_domain_configured
      estimated_monthly_cost = "~$1-5 USD (very low traffic)"
    }
    prod_environment = {
      price_class       = module.cloudfront_cost_optimized_prod.price_class
      ipv6_enabled      = module.cloudfront_cost_optimized_prod.ipv6_enabled
      monitoring_enabled = module.cloudfront_cost_optimized_prod.monitoring_enabled
      custom_domain     = module.cloudfront_cost_optimized_prod.custom_domain_configured
      estimated_monthly_cost = "~$5-50 USD (moderate traffic, regional)"
    }
    cost_savings_vs_default = {
      price_class_savings = "30-50% by using PriceClass_200 instead of PriceClass_All"
      ipv6_savings       = "No additional IPv6 charges"
      monitoring_savings = "~$0.30/alarm/month saved in dev"
      logging_savings    = "S3 storage costs saved"
    }
  }
}

# Example of how to enable features only when needed
locals {
  # Enable expensive features only for production
  enable_waf = var.environment == "prod"
  enable_logging = var.environment == "prod" && var.compliance_required
  enable_global_distribution = var.environment == "prod" && var.global_users
}

# Conditional WAF (only for production)
resource "aws_wafv2_web_acl" "main" {
  count = local.enable_waf ? 1 : 0
  
  name  = "my-app-${var.environment}-waf"
  scope = "CLOUDFRONT"
  
  default_action {
    allow {}
  }
  
  # Basic rate limiting rule
  rule {
    name     = "RateLimitRule"
    priority = 1
    
    action {
      block {}
    }
    
    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = false  # Disable to save costs
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = false  # Disable to save costs
    }
  }
  
  visibility_config {
    cloudwatch_metrics_enabled = false  # Disable to save costs
    metric_name                = "MyAppWAF"
    sampled_requests_enabled   = false  # Disable to save costs
  }
}

# Variables for cost control
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "compliance_required" {
  description = "Whether compliance logging is required"
  type        = bool
  default     = false
}

variable "global_users" {
  description = "Whether the application has global users requiring PriceClass_All"
  type        = bool
  default     = false
}