# S3 Website Module Configuration for Production Environment

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
  source = "../../../modules/s3-website"
}

# No dependencies for S3 website module

# Module-specific inputs - all configuration comes from environment
inputs = {
  # Bucket naming from environment config
  bucket_name_prefix = "inversiva-prod-website"
  
  # Website configuration
  index_document = "index.html"
  error_document = "error.html"
  
  # All S3 configuration from environment
  enable_versioning                        = local.prod_config.s3.enable_versioning
  enable_lifecycle_policy                  = local.prod_config.s3.enable_lifecycle_policy
  lifecycle_transition_ia_days             = local.prod_config.s3.lifecycle_transition_ia_days
  lifecycle_transition_glacier_days        = local.prod_config.s3.lifecycle_transition_glacier_days
  lifecycle_noncurrent_version_expiration_days = local.prod_config.s3.lifecycle_noncurrent_version_expiration_days
  
  # Production-specific S3 settings (cost-optimized)
  enable_intelligent_tiering = local.prod_config.s3.enable_intelligent_tiering
  access_logging_bucket = local.prod_config.s3.access_logging_bucket
  enable_server_side_encryption = local.prod_config.s3.enable_server_side_encryption
  kms_master_key_id = local.prod_config.s3.kms_master_key_id
  enable_bucket_key = local.prod_config.s3.enable_bucket_key
  
  # CORS configuration from environment
  cors_allowed_origins = local.prod_config.cors.allow_origins
  cors_allowed_methods = local.prod_config.cors.allow_methods
  cors_allowed_headers = local.prod_config.cors.allow_headers
  cors_expose_headers = local.prod_config.cors.expose_headers
  cors_max_age_seconds = local.prod_config.cors.max_age_seconds
  
  # Monitoring and notifications (disabled for cost optimization)
  enable_event_notifications = local.prod_config.s3.enable_event_notifications
}