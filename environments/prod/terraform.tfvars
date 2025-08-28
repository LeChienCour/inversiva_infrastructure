# Auto-generated terraform.tfvars from environment variables
# Generated on: do., 24 de ago. de 2025 18:51:37
# Environment: prod

# Project Configuration
project_name = "terraform-nextjs-infrastructure"
environment  = "prod"
aws_region   = "us-east-1"

# Domain Configuration
domain_name = "placeholder.mx"
root_domain = "placeholder.mx"

# Tags Configuration
cost_center = "production"
owner       = "platform-team"

# Cognito Configuration
cognito_min_password_length          = 12
cognito_require_lowercase            = true
cognito_require_numbers              = true
cognito_require_symbols              = true
cognito_require_uppercase            = true
cognito_temp_password_validity       = 3
cognito_mfa_configuration            = "ON"
cognito_explicit_auth_flows          = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
cognito_allowed_oauth_flows          = ["code"]
cognito_allowed_oauth_scopes         = ["email", "openid", "profile"]
cognito_callback_urls                = ["https://placeholder.mx/auth/callback"]
cognito_logout_urls                  = ["https://placeholder.mx/auth/logout"]
cognito_access_token_validity        = 1
cognito_id_token_validity            = 1
cognito_refresh_token_validity       = 30
cognito_allow_unauthenticated_identities = false

# S3 Configuration
s3_enable_versioning                     = true
s3_enable_lifecycle_policy               = true
s3_enable_intelligent_tiering            = false
s3_enable_object_lock                    = false
s3_lifecycle_transition_ia_days          = 7
s3_lifecycle_transition_glacier_days     = 30
s3_noncurrent_version_expiration_days    = 30
s3_content_bucket_prefix                 = "inversiva-prod-content"
s3_presigned_url_expiration_seconds      = 900

# CloudFront Configuration
cloudfront_price_class             = "PriceClass_100"
cloudfront_enable_ipv6             = false
cloudfront_enable_monitoring       = false
cloudfront_content_security_policy = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:; frame-ancestors 'none'; base-uri 'self'; form-action 'self';"
cloudfront_error_caching_min_ttl   = 86400
cloudfront_logging_include_cookies = false

# Route53 Configuration
route53_create_hosted_zone             = true
route53_enable_health_check            = false
route53_enable_ipv6                    = false
route53_health_check_path              = "/"
route53_health_check_failure_threshold = 3
route53_health_check_request_interval  = 30

# CORS Configuration
cors_allow_credentials = true
cors_allow_headers     = ["Accept", "Accept-Language", "Content-Language", "Content-Type", "Authorization", "X-Requested-With"]
cors_allow_methods     = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
cors_allow_origins     = ["https://placeholder.mx"]
cors_expose_headers    = ["ETag", "x-amz-meta-*"]
cors_max_age_seconds   = 86400

# Common Tags
common_tags = {
  Project     = "terraform-nextjs-infrastructure"
  Environment = "prod"
  ManagedBy   = "terraform"
  CreatedBy   = "terraform"
  CostCenter  = "production"
  Owner       = "platform-team"
}
