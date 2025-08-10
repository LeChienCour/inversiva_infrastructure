# Cognito Module Configuration for Production Environment

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
  source = "../../../modules/cognito"
}

# Dependencies - will be updated after S3 content is deployed
dependencies {
  paths = ["../s3-content"]
}

dependency "s3_content" {
  config_path = "../s3-content"
  
  mock_outputs = {
    bucket_arn = "arn:aws:s3:::inversiva-prod-content-example123"
  }
  
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  
  # Skip dependency if it doesn't exist yet
  skip_outputs = true
}

# Module-specific inputs - all configuration comes from environment
inputs = {
  # S3 content bucket integration
  content_bucket_arn = try(dependency.s3_content.outputs.bucket_arn, "")
  
  # All Cognito configuration from environment
  password_policy                  = local.prod_config.cognito.password_policy
  mfa_configuration               = local.prod_config.cognito.mfa_configuration
  explicit_auth_flows             = local.prod_config.cognito.explicit_auth_flows
  allowed_oauth_flows             = local.prod_config.cognito.allowed_oauth_flows
  allowed_oauth_scopes            = local.prod_config.cognito.allowed_oauth_scopes
  callback_urls                   = local.prod_config.cognito.callback_urls
  logout_urls                     = local.prod_config.cognito.logout_urls
  token_validity                  = local.prod_config.cognito.token_validity
  allow_unauthenticated_identities = local.prod_config.cognito.allow_unauthenticated_identities
  
  # Production-specific security settings
  advanced_security_mode = local.prod_config.cognito.advanced_security_mode
  account_recovery_setting = local.prod_config.cognito.account_recovery_setting
  user_pool_add_ons = local.prod_config.cognito.user_pool_add_ons
}