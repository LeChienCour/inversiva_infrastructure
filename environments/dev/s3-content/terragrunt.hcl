# S3 Content Module Configuration for Development Environment

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
  source = "../../../modules/s3-content"
}

# Dependencies - S3 content depends on Cognito for user authentication
dependencies {
  paths = ["../cognito"]
}

# Dependency outputs
dependency "cognito" {
  config_path = "../cognito"
  
  mock_outputs = {
    user_pool_arn = "arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_EXAMPLE"
  }
  
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# Module-specific inputs - all configuration comes from environment
inputs = {
  # Basic configuration
  project_name = include.env.locals.project_name
  environment  = include.env.locals.environment
  
  # Bucket naming from environment config
  bucket_name_prefix = include.env.locals.dev_config.s3.content_bucket_prefix
  
  # Cognito integration
  cognito_user_pool_arn = dependency.cognito.outputs.user_pool_arn
  
  # All S3 configuration from environment
  enable_versioning                        = include.env.locals.dev_config.s3.enable_versioning
  enable_lifecycle_policy                  = include.env.locals.dev_config.s3.enable_lifecycle_policy
  lifecycle_transition_ia_days             = include.env.locals.dev_config.s3.lifecycle_transition_ia_days
  lifecycle_transition_glacier_days        = include.env.locals.dev_config.s3.lifecycle_transition_glacier_days
  lifecycle_noncurrent_version_expiration_days = include.env.locals.dev_config.s3.noncurrent_version_expiration_days
  
  # CORS configuration from environment
  cors_allowed_origins = include.env.locals.dev_config.cors.allow_origins
  
  # Presigned URL configuration from environment
  presigned_url_expiration_seconds = include.env.locals.dev_config.s3.presigned_url_expiration_seconds
}