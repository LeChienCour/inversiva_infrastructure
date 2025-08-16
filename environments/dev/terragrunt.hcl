# Development Environment Configuration
# This file contains ALL environment-specific configuration for the development environment

# This file provides environment-specific configuration
# Components will include the root directly and merge this configuration

# Provider configuration is handled by the root terragrunt.hcl

locals {
  # Environment-specific variables
  environment = "dev"
  project_name = "terraform-nextjs-infrastructure"  # Must match root terragrunt.hcl
  
  # Domain configuration for development
  domain_name = "dev.placeholder.mx"
  root_domain = "placeholder.mx"
  
  # All development configuration in one place
  dev_config = {
    # === COGNITO CONFIGURATION ===
    cognito = {
      password_policy = {
        minimum_length                   = 8
        require_lowercase                = true
        require_numbers                  = true
        require_symbols                  = false  # Relaxed for dev
        require_uppercase                = true
        temporary_password_validity_days = 7
      }
      
      mfa_configuration = "OPTIONAL"
      
      explicit_auth_flows = [
        "ALLOW_USER_SRP_AUTH",
        "ALLOW_REFRESH_TOKEN_AUTH",
        "ALLOW_USER_PASSWORD_AUTH"
      ]
      
      allowed_oauth_flows = ["code", "implicit"]
      allowed_oauth_scopes = ["email", "openid", "profile"]
      
      callback_urls = [
        "http://localhost:3000/auth/callback",
        "https://${local.domain_name}/auth/callback"
      ]
      
      logout_urls = [
        "http://localhost:3000/auth/logout",
        "https://${local.domain_name}/auth/logout"
      ]
      
      token_validity = {
        access_token  = 1   # 1 hour
        id_token      = 1   # 1 hour
        refresh_token = 7   # 7 days
      }
      
      allow_unauthenticated_identities = true
    }
    
    # === S3 CONFIGURATION ===
    s3 = {
      enable_versioning = false  # Cost optimization
      enable_lifecycle_policy = true
      enable_intelligent_tiering = false
      enable_object_lock = false
      access_logging_bucket = null
      
      # Lifecycle policies
      lifecycle_transition_ia_days = 7
      lifecycle_transition_glacier_days = 30
      noncurrent_version_expiration_days = 30
      
      # Content bucket
      content_bucket_prefix = "inversiva-dev-content"
      presigned_url_expiration_seconds = 300  # 5 minutes
    }
    
    # === CLOUDFRONT CONFIGURATION ===
    cloudfront = {
      price_class = "PriceClass_100"  # North America + Europe only
      enable_ipv6 = false
      enable_monitoring = false
      minimum_tls_version = "TLSv1.2_2021"
      
      # Security headers (relaxed for dev)
      content_security_policy = "default-src 'self' 'unsafe-inline' 'unsafe-eval'; script-src 'self' 'unsafe-inline' 'unsafe-eval' localhost:*; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https: localhost:*; frame-ancestors 'none';"
      
      # Error handling for Next.js SPA
      custom_error_responses = [
        {
          error_code            = 404
          response_code         = 200
          response_page_path    = "/index.html"
          error_caching_min_ttl = 300
        },
        {
          error_code            = 403
          response_code         = 200
          response_page_path    = "/index.html"
          error_caching_min_ttl = 300
        }
      ]
      
      # Logging disabled for cost savings
      logging_bucket = null
      logging_include_cookies = false
    }
    
    # === ROUTE53 CONFIGURATION ===
    route53 = {
      create_hosted_zone = false   # Use existing zone to save costs
      enable_health_check = false  # Disable health checks to save costs
      enable_ipv6 = false
      
      health_check_path = "/"
      health_check_failure_threshold = 3
      health_check_request_interval = 30
    }
    
    # === CORS CONFIGURATION (shared across services) ===
    cors = {
      allow_credentials = false
      allow_headers = ["Accept", "Accept-Language", "Content-Language", "Content-Type", "Authorization"]
      allow_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      allow_origins = [
        "http://localhost:3000",
        "https://${local.domain_name}"
      ]
      expose_headers = []
      max_age_seconds = 86400
    }
  }
  
  # Development-specific tags
  dev_tags = {
    Environment = local.environment
    CostCenter  = "development"
    AutoShutdown = "enabled"
    Owner       = "dev-team"
  }
}

# Environment-specific inputs that all modules can access
inputs = {
  project_name = local.project_name
  environment = local.environment
  domain_name = local.domain_name
  root_domain = local.root_domain
  
  # Pass the entire dev config so modules can pick what they need
  dev_config = local.dev_config
  
  # Development-specific tags
  environment_tags = local.dev_tags
}