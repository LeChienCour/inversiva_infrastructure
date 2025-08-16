# Cognito Module Configuration for Production Environment

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