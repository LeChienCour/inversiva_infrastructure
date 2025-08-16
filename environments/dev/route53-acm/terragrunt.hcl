# Route53 and ACM Module Configuration for Development Environment

# Include the root terragrunt configuration
include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

# Include environment-specific configuration
include "env" {
  path = "../terragrunt.hcl"
  expose = true
}

# Configure the terraform source
terraform {
  source = "../../../modules/route53-acm"
}

# No dependencies - this is typically one of the first modules to be deployed

# Module-specific inputs - all configuration comes from environment
inputs = {
  # Basic configuration
  project_name = include.env.locals.project_name
  environment  = include.env.locals.environment
  
  # Domain configuration from environment
  domain_name = include.env.locals.root_domain
  subdomain = include.env.locals.environment  # Creates dev.placeholder.mx
  
  # All Route53 configuration from environment
  create_hosted_zone = include.env.locals.dev_config.route53.create_hosted_zone
  enable_health_check = include.env.locals.dev_config.route53.enable_health_check
  enable_ipv6 = include.env.locals.dev_config.route53.enable_ipv6
  
  # Health check configuration from environment
  health_check_path = include.env.locals.dev_config.route53.health_check_path
  health_check_failure_threshold = include.env.locals.dev_config.route53.health_check_failure_threshold
  health_check_request_interval = include.env.locals.dev_config.route53.health_check_request_interval
  
  # CloudFront integration (will be populated by dependency)
  cloudfront_distribution_domain_name = null
  cloudfront_distribution_hosted_zone_id = null
  
  # Cost optimization settings
  cost_optimization_enabled = true
  dev_cost_optimizations = {
    create_hosted_zone  = include.env.locals.dev_config.route53.create_hosted_zone
    enable_health_check = include.env.locals.dev_config.route53.enable_health_check
    enable_ipv6         = include.env.locals.dev_config.route53.enable_ipv6
  }
}