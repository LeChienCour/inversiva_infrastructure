# Route53 and ACM Module Configuration for Production Environment

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

# No dependencies for Route53/ACM module - it's typically deployed first

# Module-specific inputs - all configuration comes from environment
inputs = {
  # Domain configuration from environment
  domain_name = local.domain_name
  root_domain = local.root_domain
  
  # Route53 configuration from environment
  create_hosted_zone = local.prod_config.route53.create_hosted_zone
  enable_health_check = local.prod_config.route53.enable_health_check
  enable_ipv6 = local.prod_config.route53.enable_ipv6
  
  # Health check configuration (disabled for cost optimization)
  health_check_path = local.prod_config.route53.health_check_path
  health_check_failure_threshold = local.prod_config.route53.health_check_failure_threshold
  health_check_request_interval = local.prod_config.route53.health_check_request_interval
  health_check_regions = local.prod_config.route53.health_check_regions
  
  # ACM certificate configuration
  certificate_transparency_logging_preference = "ENABLED"
  
  # Subject alternative names for production
  subject_alternative_names = [
    "www.${local.domain_name}",
    "api.${local.domain_name}"
  ]
  
  # Certificate validation method
  validation_method = "DNS"
  
  # Certificate lifecycle
  certificate_lifecycle = {
    create_before_destroy = true
  }
}