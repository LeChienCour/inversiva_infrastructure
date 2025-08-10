# S3 Website Module Configuration for Development Environment

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
  source = "../../../modules/s3-website"
}

# No dependencies - S3 website is created independently

# Module-specific inputs - all configuration comes from environment
inputs = {
  # CloudFront integration (will be configured after CloudFront is created)
  cloudfront_distribution_arn = null  # Will be updated after CloudFront deployment
  
  # Website configuration
  index_document = "index.html"
  error_document = "error.html"
  
  # All S3 configuration from environment
  enable_versioning = local.dev_config.s3.enable_versioning
  enable_lifecycle_policy = local.dev_config.s3.enable_lifecycle_policy
  enable_intelligent_tiering = local.dev_config.s3.enable_intelligent_tiering
  enable_object_lock = local.dev_config.s3.enable_object_lock
  access_logging_bucket = local.dev_config.s3.access_logging_bucket
  
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