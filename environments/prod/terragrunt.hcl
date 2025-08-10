# Production Environment Configuration
# This file contains ALL environment-specific configuration for the production environment

# Include the root terragrunt configuration
include "root" {
  path = find_in_parent_folders()
}

locals {
  # Environment-specific variables
  environment = "prod"
  
  # Domain configuration for production
  domain_name = "placeholder.mx"
  root_domain = "placeholder.mx"
  
  # All production configuration in one place
  prod_config = {
    # === COGNITO CONFIGURATION ===
    cognito = {
      password_policy = {
        minimum_length                   = 12  # Stronger password requirement
        require_lowercase                = true
        require_numbers                  = true
        require_symbols                  = true  # Required for production
        require_uppercase                = true
        temporary_password_validity_days = 3    # Shorter validity for security
      }
      
      mfa_configuration = "ON"  # MFA required for production
      
      explicit_auth_flows = [
        "ALLOW_USER_SRP_AUTH",
        "ALLOW_REFRESH_TOKEN_AUTH"
        # Removed ALLOW_USER_PASSWORD_AUTH for enhanced security
      ]
      
      allowed_oauth_flows = ["code"]  # Only authorization code flow for security
      allowed_oauth_scopes = ["email", "openid", "profile"]
      
      callback_urls = [
        "https://${local.domain_name}/auth/callback"
        # No localhost URLs in production
      ]
      
      logout_urls = [
        "https://${local.domain_name}/auth/logout"
        # No localhost URLs in production
      ]
      
      token_validity = {
        access_token  = 1   # 1 hour
        id_token      = 1   # 1 hour
        refresh_token = 30  # 30 days for better UX in production
      }
      
      allow_unauthenticated_identities = false  # Enhanced security
      
      # Advanced threat protection for production
      advanced_security_mode = "ENFORCED"
      
      # Account recovery settings
      account_recovery_setting = {
        recovery_mechanisms = [
          {
            name     = "verified_email"
            priority = 1
          }
        ]
      }
      
      # User pool add-ons
      user_pool_add_ons = {
        advanced_security_mode = "ENFORCED"
      }
    }
    
    # === S3 CONFIGURATION ===
    s3 = {
      enable_versioning = true  # Keep versioning for data protection
      enable_lifecycle_policy = true
      enable_intelligent_tiering = false  # Disable to avoid monitoring fees for small usage
      enable_object_lock = false  # Disable object lock to reduce costs
      access_logging_bucket = null  # Disable access logging to save costs
      
      # Aggressive lifecycle policies for cost optimization
      lifecycle_transition_ia_days = 7   # Quick transition to cheaper storage
      lifecycle_transition_glacier_days = 30  # Faster archival
      noncurrent_version_expiration_days = 30  # Shorter retention for cost savings
      
      # Content bucket
      content_bucket_prefix = "inversiva-prod-content"
      presigned_url_expiration_seconds = 900  # 15 minutes for production
      
      # Enhanced security settings (keep for security)
      enable_server_side_encryption = true
      kms_master_key_id = "alias/aws/s3"  # Use AWS managed key (free)
      enable_bucket_key = true
      
      # Public access block (strict for production)
      block_public_acls       = true
      block_public_policy     = true
      ignore_public_acls      = true
      restrict_public_buckets = true
      
      # Disable notifications to save costs
      enable_event_notifications = false
    }
    
    # === CLOUDFRONT CONFIGURATION ===
    cloudfront = {
      price_class = "PriceClass_100"  # Regional distribution for cost optimization
      enable_ipv6 = false  # Disable IPv6 to reduce complexity and potential costs
      enable_monitoring = false  # Disable detailed monitoring to save costs
      minimum_tls_version = "TLSv1.2_2021"
      
      # Strict security headers for production
      content_security_policy = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:; frame-ancestors 'none'; base-uri 'self'; form-action 'self';"
      
      # Error handling for Next.js SPA
      custom_error_responses = [
        {
          error_code            = 404
          response_code         = 200
          response_page_path    = "/index.html"
          error_caching_min_ttl = 86400  # Longer caching for production
        },
        {
          error_code            = 403
          response_code         = 200
          response_page_path    = "/index.html"
          error_caching_min_ttl = 86400
        }
      ]
      
      # Disable logging to save costs for small apps
      logging_bucket = null
      logging_include_cookies = false
      
      # WAF integration disabled for cost optimization
      web_acl_id = null
      
      # Enhanced caching for production
      default_cache_behavior = {
        compress               = true
        viewer_protocol_policy = "redirect-to-https"
        allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods         = ["GET", "HEAD"]
        
        # Optimized TTL for production
        default_ttl = 86400   # 1 day
        max_ttl     = 31536000 # 1 year
        min_ttl     = 0
        
        # Forward headers for Next.js
        forward_headers = ["Authorization", "CloudFront-Forwarded-Proto"]
      }
      
      # Geographic restrictions (can be configured as needed)
      geo_restriction_type = "none"
      geo_restriction_locations = []
    }
    
    # === ROUTE53 CONFIGURATION ===
    route53 = {
      create_hosted_zone = true   # Create hosted zone for production domain
      enable_health_check = false  # Disable health checks to save $1.50/month
      enable_ipv6 = false  # Disable IPv6 for simplicity and cost savings
      
      health_check_path = "/"
      health_check_failure_threshold = 3
      health_check_request_interval = 30
      
      # Health check configuration (disabled for cost optimization)
      health_check_regions = []
    }
    
    # === CORS CONFIGURATION (shared across services) ===
    cors = {
      allow_credentials = true  # Enable credentials for production
      allow_headers = ["Accept", "Accept-Language", "Content-Language", "Content-Type", "Authorization", "X-Requested-With"]
      allow_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      allow_origins = [
        "https://${local.domain_name}"
        # Only production domain, no localhost
      ]
      expose_headers = ["ETag", "x-amz-meta-*"]
      max_age_seconds = 86400
    }
    
    # === MONITORING AND ALERTING ===
    monitoring = {
      enable_cloudwatch_alarms = false  # Disable detailed alarms to save costs
      enable_cost_alerts = true  # Keep cost alerts for budget management
      enable_security_alerts = false  # Disable to reduce CloudWatch costs
      
      # CloudWatch log retention (shorter for cost savings)
      log_retention_days = 30
      
      # SNS topics for alerts
      alert_email = "alerts@placeholder.mx"
      
      # Cost thresholds (adjusted for small app)
      monthly_cost_threshold = 25  # USD - realistic for small app
      daily_cost_threshold = 2     # USD - realistic daily threshold
    }
    
    # === BACKUP AND DISASTER RECOVERY ===
    backup = {
      enable_cross_region_replication = false  # Disable to save significant costs
      backup_region = "us-west-2"
      backup_retention_days = 30  # Shorter retention for cost savings
      
      # Point-in-time recovery (disable for cost optimization)
      enable_point_in_time_recovery = false
    }
  }
  
  # Production-specific tags
  prod_tags = {
    Environment = local.environment
    CostCenter  = "production"
    AutoShutdown = "disabled"
    Owner       = "platform-team"
    Compliance  = "required"
    DataClassification = "confidential"
    BackupRequired = "true"
    MonitoringLevel = "enhanced"
  }
}

# Environment-specific inputs that all modules can access
inputs = {
  environment = local.environment
  domain_name = local.domain_name
  root_domain = local.root_domain
  
  # Pass the entire prod config so modules can pick what they need
  prod_config = local.prod_config
  
  # Production-specific tags
  environment_tags = local.prod_tags
}