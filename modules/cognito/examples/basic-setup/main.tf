# Basic Cognito setup for development environment
module "cognito" {
  source = "../../"

  project_name = "nextjs-app"
  environment  = "dev"

  # Development-friendly callback URLs
  callback_urls = [
    "http://localhost:3000/auth/callback",
    "https://dev.example.com/auth/callback"
  ]
  
  logout_urls = [
    "http://localhost:3000/auth/logout",
    "https://dev.example.com/auth/logout"
  ]

  # Relaxed password policy for development
  password_policy = {
    minimum_length                   = 8
    require_lowercase               = true
    require_numbers                 = true
    require_symbols                 = false
    require_uppercase               = false
    temporary_password_validity_days = 7
  }

  # Optional MFA for development
  mfa_configuration = "OPTIONAL"

  tags = {
    Environment = "dev"
    Project     = "nextjs-app"
    ManagedBy   = "terraform"
  }
}

# Output the configuration for frontend use
output "cognito_config" {
  description = "Cognito configuration for Next.js application"
  value       = module.cognito.cognito_config
}