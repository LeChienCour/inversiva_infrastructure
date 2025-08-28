# Auto-generated terraform.tfvars from environment variables
# Generated on: do., 24 de ago. de 2025 21:34:30
# Environment: dev

# Project Configuration
project_name = "terraform-nextjs-infrastructure"
environment  = "dev"
aws_region   = "us-east-1"

# Domain Configuration
domain_name = "inmersa.mx"
root_domain = "inmersa.mx"

# Tags Configuration
cost_center = "development"
owner       = "dev-team"

# Cognito Configuration
cognito_min_password_length          = 8
cognito_require_lowercase            = true
cognito_require_numbers              = true
cognito_require_symbols              = false
cognito_require_uppercase            = true
cognito_temp_password_validity       = 7
cognito_mfa_configuration            = "OPTIONAL"
cognito_explicit_auth_flows          = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_PASSWORD_AUTH"]
cognito_allowed_oauth_flows          = ["code", "implicit"]
cognito_allowed_oauth_scopes         = ["email", "openid", "profile"]
cognito_callback_urls                = ["http://localhost:3000/auth/callback", "https://inmersa.mx/auth/callback"]
cognito_logout_urls                  = ["http://localhost:3000/auth/logout", "https://inmersa.mx/auth/logout"]
cognito_access_token_validity        = 1
cognito_id_token_validity            = 1
cognito_refresh_token_validity       = 7
cognito_allow_unauthenticated_identities = true

# S3 Configuration
s3_enable_versioning                     = false
s3_enable_lifecycle_policy               = true
s3_enable_intelligent_tiering            = false
s3_enable_object_lock                    = false
s3_lifecycle_transition_ia_days          = 30
s3_lifecycle_transition_glacier_days     = 90
s3_noncurrent_version_expiration_days    = 30
s3_content_bucket_prefix                 = "inversiva-dev-content"
s3_presigned_url_expiration_seconds      = 300

# CloudFront Configuration
cloudfront_price_class             = "PriceClass_100"
cloudfront_enable_ipv6             = false
cloudfront_enable_monitoring       = false
cloudfront_content_security_policy = "default-src 'self' 'unsafe-inline' 'unsafe-eval'; script-src 'self' 'unsafe-inline' 'unsafe-eval' localhost:*; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https: localhost:*; frame-ancestors 'none';"
cloudfront_error_caching_min_ttl   = 300
cloudfront_logging_include_cookies = false

# Route53 Configuration
route53_create_hosted_zone             = true
route53_enable_health_check            = false
route53_enable_ipv6                    = false
route53_health_check_path              = "/"
route53_health_check_failure_threshold = 3
route53_health_check_request_interval  = 30

# CORS Configuration
cors_allow_credentials = false
cors_allow_headers     = ["Accept", "Accept-Language", "Content-Language", "Content-Type", "Authorization"]
cors_allow_methods     = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
cors_allow_origins     = ["http://localhost:3000", "https://inmersa.mx"]

cors_max_age_seconds   = 86400

# Common Tags
common_tags = {
  Project     = "terraform-nextjs-infrastructure"
  Environment = "dev"
  ManagedBy   = "terraform"
  CreatedBy   = "terraform"
  CostCenter  = "development"
  Owner       = "dev-team"
}
