# Cognito Module Configuration for Development Environment

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
    bucket_arn = "arn:aws:s3:::inversiva-dev-content-example123"
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
  password_policy                  = local.dev_config.cognito.password_policy
  mfa_configuration               = local.dev_config.cognito.mfa_configuration
  explicit_auth_flows             = local.dev_config.cognito.explicit_auth_flows
  allowed_oauth_flows             = local.dev_config.cognito.allowed_oauth_flows
  allowed_oauth_scopes            = local.dev_config.cognito.allowed_oauth_scopes
  callback_urls                   = local.dev_config.cognito.callback_urls
  logout_urls                     = local.dev_config.cognito.logout_urls
  token_validity                  = local.dev_config.cognito.token_validity
  allow_unauthenticated_identities = local.dev_config.cognito.allow_unauthenticated_identities
}