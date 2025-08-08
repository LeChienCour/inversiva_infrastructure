output "user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.arn
}

output "user_pool_endpoint" {
  description = "Endpoint name of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.endpoint
}

output "user_pool_domain" {
  description = "Domain of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.domain
}

output "user_pool_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.main.id
}

output "user_pool_client_secret" {
  description = "Secret of the Cognito User Pool Client (if generated)"
  value       = aws_cognito_user_pool_client.main.client_secret
  sensitive   = true
}

output "identity_pool_id" {
  description = "ID of the Cognito Identity Pool"
  value       = aws_cognito_identity_pool.main.id
}

output "identity_pool_arn" {
  description = "ARN of the Cognito Identity Pool"
  value       = aws_cognito_identity_pool.main.arn
}

output "authenticated_role_arn" {
  description = "ARN of the IAM role for authenticated users"
  value       = aws_iam_role.authenticated.arn
}

output "unauthenticated_role_arn" {
  description = "ARN of the IAM role for unauthenticated users (if enabled)"
  value       = var.allow_unauthenticated_identities ? aws_iam_role.unauthenticated[0].arn : null
}

output "cognito_config" {
  description = "Complete Cognito configuration for frontend integration"
  value = {
    user_pool_id        = aws_cognito_user_pool.main.id
    user_pool_client_id = aws_cognito_user_pool_client.main.id
    identity_pool_id    = aws_cognito_identity_pool.main.id
    region              = data.aws_region.current.id
    oauth = {
      domain        = aws_cognito_user_pool.main.domain
      scope         = var.allowed_oauth_scopes
      redirect_uri  = var.callback_urls[0]
      response_type = "code"
    }
  }
}

# Data source for current AWS region
data "aws_region" "current" {}