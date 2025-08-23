# Production Environment - Terraform Variables Template
# This file contains the default values for the production environment
# Values can be overridden by environment variables loaded from config/prod.env
#
# Usage:
# 1. Copy this file to terraform.tfvars.local for local development (optional)
# 2. Use deployment script to load values from config/prod.env
# 3. Modify values directly in this file for permanent changes
#
# IMPORTANT: Review all values before production deployment

# === CORE PROJECT VARIABLES ===
project_name = "terraform-nextjs-infrastructure"
environment  = "prod"
aws_region   = "us-east-1"

# === DOMAIN CONFIGURATION ===
domain_name = "placeholder.mx"
root_domain = "placeholder.mx"

# === TAGGING VARIABLES ===
cost_center          = "production"
owner               = "platform-team"
auto_shutdown       = "disabled"
compliance          = "required"
data_classification = "confidential"
backup_required     = "true"
monitoring_level    = "enhanced"

# === COGNITO CONFIGURATION ===
cognito_min_password_length              = 12
cognito_require_lowercase                = true
cognito_require_numbers                  = true
cognito_require_symbols                  = true
cognito_require_uppercase                = true
cognito_temp_password_validity           = 3
cognito_mfa_configuration                = "ON"
cognito_explicit_auth_flows              = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
cognito_allowed_oauth_flows              = ["code"]
cognito_allowed_oauth_scopes             = ["email", "openid", "profile"]
cognito_callback_urls                    = ["https://placeholder.mx/auth/callback"]
cognito_logout_urls                      = ["https://placeholder.mx/auth/logout"]
cognito_access_token_validity            = 1
cognito_id_token_validity                = 1
cognito_refresh_token_validity           = 30
cognito_allow_unauthenticated_identities = false

# === S3 CONFIGURATION ===
s3_enable_versioning                     = true
s3_enable_lifecycle_policy               = true
s3_enable_intelligent_tiering            = false
s3_enable_object_lock                    = false
s3_lifecycle_transition_ia_days          = 7
s3_lifecycle_transition_glacier_days     = 30
s3_noncurrent_version_expiration_days    = 30
s3_content_bucket_prefix                 = "inversiva-prod-content"
s3_presigned_url_expiration_seconds      = 900
s3_enable_server_side_encryption         = true
s3_kms_master_key_id                     = "alias/aws/s3"
s3_enable_bucket_key                     = true
s3_enable_event_notifications            = false

# === CLOUDFRONT CONFIGURATION ===
cloudfront_price_class                = "PriceClass_100"
cloudfront_enable_ipv6                = false
cloudfront_enable_monitoring          = false
cloudfront_content_security_policy    = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:; frame-ancestors 'none'; base-uri 'self'; form-action 'self';"
cloudfront_error_caching_min_ttl      = 86400
cloudfront_logging_include_cookies    = false

cloudfront_geo_restriction_type       = "none"

# === ROUTE53 CONFIGURATION ===
route53_create_hosted_zone             = true
route53_enable_health_check            = false
route53_enable_ipv6                    = false
route53_health_check_path              = "/"
route53_health_check_failure_threshold = 3
route53_health_check_request_interval  = 30

# === CORS CONFIGURATION ===
cors_allow_credentials = true
cors_allow_headers     = ["Accept", "Accept-Language", "Content-Language", "Content-Type", "Authorization", "X-Requested-With"]
cors_allow_methods     = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
cors_allow_origins     = ["https://placeholder.mx"]
cors_expose_headers    = ["ETag", "x-amz-meta-*"]
cors_max_age_seconds   = 86400

# === MONITORING CONFIGURATION ===
monitoring_enable_cloudwatch_alarms = false
monitoring_enable_cost_alerts       = true
monitoring_enable_security_alerts   = false
monitoring_log_retention_days       = 30
monitoring_alert_email              = "alerts@placeholder.mx"
monitoring_monthly_cost_threshold   = 25
monitoring_daily_cost_threshold     = 2

# === BACKUP CONFIGURATION ===
backup_enable_cross_region_replication = false
backup_region                          = "us-west-2"
backup_retention_days                  = 30
backup_enable_point_in_time_recovery   = false