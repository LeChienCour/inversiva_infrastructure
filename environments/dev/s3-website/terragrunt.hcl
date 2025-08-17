# S3 Website Module Configuration for Development Environment

# Include the root terragrunt configuration (needed for remote state)
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
  source = "../../../modules/s3-website"
}

# No dependencies - S3 website is created independently

# Module-specific inputs - all configuration comes from environment
inputs = {
  # Basic configuration
  project_name = include.env.locals.project_name
  environment  = include.env.locals.environment
  
  # CloudFront integration (will be configured after CloudFront is created)
  cloudfront_distribution_arn = "arn:aws:cloudfront::123456789012:distribution/EXAMPLE123"  # Mock ARN for initial deployment
  
  # Website configuration
  index_document = "index.html"
  error_document = "error.html"
  
  # All S3 configuration from environment
  enable_versioning = include.env.locals.dev_config.s3.enable_versioning
  enable_lifecycle_policy = include.env.locals.dev_config.s3.enable_lifecycle_policy
  enable_intelligent_tiering = include.env.locals.dev_config.s3.enable_intelligent_tiering
  enable_object_lock = include.env.locals.dev_config.s3.enable_object_lock
  access_logging_bucket = include.env.locals.dev_config.s3.access_logging_bucket
  
  # Routing rules for Next.js SPA
  routing_rules = [
    {
      condition = {
        key_prefix_equals = "api/"
      }
      redirect = {
        replace_key_prefix_with = "index.html"
      }
    }
  ]
  
  # Notification configurations (empty for dev)
  notification_configurations = []
}