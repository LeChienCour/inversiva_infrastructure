# Cognito Module Configuration for Production Environment

# Include environment-specific configuration (which includes root configuration)
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
  password_policy                  = include.env.locals.prod_config.cognito.password_policy
  mfa_configuration               = include.env.locals.prod_config.cognito.mfa_configuration
  explicit_auth_flows             = include.env.locals.prod_config.cognito.explicit_auth_flows
  allowed_oauth_flows             = include.env.locals.prod_config.cognito.allowed_oauth_flows
  allowed_oauth_scopes            = include.env.locals.prod_config.cognito.allowed_oauth_scopes
  callback_urls                   = include.env.locals.prod_config.cognito.callback_urls
  logout_urls                     = include.env.locals.prod_config.cognito.logout_urls
  token_validity                  = include.env.locals.prod_config.cognito.token_validity
  allow_unauthenticated_identities = include.env.locals.prod_config.cognito.allow_unauthenticated_identities
  
  # Production-specific security settings
  advanced_security_mode = include.env.locals.prod_config.cognito.advanced_security_mode
  account_recovery_setting = include.env.locals.prod_config.cognito.account_recovery_setting
  user_pool_add_ons = include.env.locals.prod_config.cognito.user_pool_add_ons
}