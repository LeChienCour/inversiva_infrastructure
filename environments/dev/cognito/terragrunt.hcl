# Cognito Module Configuration for Development Environment

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
  source = "../../../modules/cognito"
}

# No dependencies - Cognito is a foundational service that other services depend on

# Module-specific inputs - all configuration comes from environment
inputs = {
  # Basic configuration
  project_name = include.env.locals.project_name
  environment  = include.env.locals.environment
  
  # All Cognito configuration from environment
  password_policy                  = include.env.locals.dev_config.cognito.password_policy
  mfa_configuration               = include.env.locals.dev_config.cognito.mfa_configuration
  explicit_auth_flows             = include.env.locals.dev_config.cognito.explicit_auth_flows
  allowed_oauth_flows             = include.env.locals.dev_config.cognito.allowed_oauth_flows
  allowed_oauth_scopes            = include.env.locals.dev_config.cognito.allowed_oauth_scopes
  callback_urls                   = include.env.locals.dev_config.cognito.callback_urls
  logout_urls                     = include.env.locals.dev_config.cognito.logout_urls
  token_validity                  = include.env.locals.dev_config.cognito.token_validity
  allow_unauthenticated_identities = include.env.locals.dev_config.cognito.allow_unauthenticated_identities
}