# Production Cognito setup with enhanced security
module "cognito" {
  source = "../../"

  project_name = "nextjs-app"
  environment  = "prod"

  # Production callback URLs
  callback_urls = ["https://example.com/auth/callback"]
  logout_urls   = ["https://example.com/auth/logout"]

  # Strict password policy for production
  password_policy = {
    minimum_length                   = 12
    require_lowercase               = true
    require_numbers                 = true
    require_symbols                 = true
    require_uppercase               = true
    temporary_password_validity_days = 3
  }

  # Enforce MFA for production
  mfa_configuration = "ON"

  # Shorter token validity for enhanced security
  token_validity = {
    access_token  = 1
    id_token      = 1
    refresh_token = 7
  }

  # Link to content bucket for proper IAM policies
  content_bucket_arn = var.content_bucket_arn

  tags = {
    Environment = "prod"
    Project     = "nextjs-app"
    ManagedBy   = "terraform"
    Backup      = "required"
  }
}

variable "content_bucket_arn" {
  description = "ARN of the S3 content bucket"
  type        = string
}

# Output the configuration for frontend use
output "cognito_config" {
  description = "Cognito configuration for Next.js application"
  value       = module.cognito.cognito_config
  sensitive   = true
}