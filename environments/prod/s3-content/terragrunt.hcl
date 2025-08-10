# S3 Content Module Configuration for Production Environment

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
  # Bucket naming from environment config
  bucket_name_prefix = local.prod_config.s3.content_bucket_prefix
  
  # Cognito integration
  cognito_user_pool_arn = dependency.cognito.outputs.user_pool_arn
  
  # All S3 configuration from environment
  enable_versioning                        = local.prod_config.s3.enable_versioning
  enable_lifecycle_policy                  = local.prod_config.s3.enable_lifecycle_policy
  lifecycle_transition_ia_days             = local.prod_config.s3.lifecycle_transition_ia_days
  lifecycle_transition_glacier_days        = local.prod_config.s3.lifecycle_transition_glacier_days
  lifecycle_noncurrent_version_expiration_days = local.prod_config.s3.lifecycle_noncurrent_version_expiration_days
  
  # Production-specific S3 settings (cost-optimized)
  enable_intelligent_tiering = local.prod_config.s3.enable_intelligent_tiering
  enable_object_lock = local.prod_config.s3.enable_object_lock
  access_logging_bucket = local.prod_config.s3.access_logging_bucket
  enable_server_side_encryption = local.prod_config.s3.enable_server_side_encryption
  kms_master_key_id = local.prod_config.s3.kms_master_key_id
  enable_bucket_key = local.prod_config.s3.enable_bucket_key
  
  # Enhanced security settings for production
  block_public_acls       = local.prod_config.s3.block_public_acls
  block_public_policy     = local.prod_config.s3.block_public_policy
  ignore_public_acls      = local.prod_config.s3.ignore_public_acls
  restrict_public_buckets = local.prod_config.s3.restrict_public_buckets
  
  # CORS configuration from environment
  cors_allowed_origins = local.prod_config.cors.allow_origins
  
  # Presigned URL configuration from environment
  presigned_url_expiration_seconds = local.prod_config.s3.presigned_url_expiration_seconds
  
  # Monitoring and notifications (disabled for cost optimization)
  enable_event_notifications = local.prod_config.s3.enable_event_notifications
}