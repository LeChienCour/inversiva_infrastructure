# Development Environment - Variable Definitions
# This file defines all variables with validation rules for the development environment

# === CORE PROJECT VARIABLES ===

variable "project_name" {
  description = "Name of the project, used for resource naming"
  type        = string
  default     = "terraform-nextjs-infrastructure"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be either 'dev' or 'prod'."
  }
}

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be in the format like 'us-east-1'."
  }
}

# === DOMAIN CONFIGURATION ===

variable "domain_name" {
  description = "Primary domain name for the application"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9.-]+\\.[a-z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid domain format."
  }
}

variable "root_domain" {
  description = "Root domain name (without subdomain)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9.-]+\\.[a-z]{2,}$", var.root_domain))
    error_message = "Root domain must be a valid domain format."
  }
}

# === TAGGING VARIABLES ===

variable "cost_center" {
  description = "Cost center for resource tagging"
  type        = string
  default     = "development"
}

variable "owner" {
  description = "Owner of the resources for tagging"
  type        = string
  default     = "dev-team"
}

# === COGNITO CONFIGURATION ===

variable "cognito_min_password_length" {
  description = "Minimum password length for Cognito user pool"
  type        = number
  default     = 8
  validation {
    condition     = var.cognito_min_password_length >= 6 && var.cognito_min_password_length <= 99
    error_message = "Password length must be between 6 and 99 characters."
  }
}

variable "cognito_require_lowercase" {
  description = "Require lowercase letters in passwords"
  type        = bool
  default     = true
}

variable "cognito_require_numbers" {
  description = "Require numbers in passwords"
  type        = bool
  default     = true
}

variable "cognito_require_symbols" {
  description = "Require symbols in passwords"
  type        = bool
  default     = false
}

variable "cognito_require_uppercase" {
  description = "Require uppercase letters in passwords"
  type        = bool
  default     = true
}

variable "cognito_temp_password_validity" {
  description = "Temporary password validity in days"
  type        = number
  default     = 7
  validation {
    condition     = var.cognito_temp_password_validity >= 1 && var.cognito_temp_password_validity <= 365
    error_message = "Temporary password validity must be between 1 and 365 days."
  }
}

variable "cognito_mfa_configuration" {
  description = "MFA configuration for Cognito user pool"
  type        = string
  default     = "OPTIONAL"
  validation {
    condition     = contains(["OFF", "ON", "OPTIONAL"], var.cognito_mfa_configuration)
    error_message = "MFA configuration must be one of: OFF, ON, OPTIONAL."
  }
}

variable "cognito_explicit_auth_flows" {
  description = "List of authentication flows for Cognito user pool client"
  type        = list(string)
  default     = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_PASSWORD_AUTH"]
  validation {
    condition = alltrue([
      for flow in var.cognito_explicit_auth_flows : contains([
        "ALLOW_ADMIN_USER_PASSWORD_AUTH",
        "ALLOW_CUSTOM_AUTH",
        "ALLOW_USER_PASSWORD_AUTH",
        "ALLOW_USER_SRP_AUTH",
        "ALLOW_REFRESH_TOKEN_AUTH"
      ], flow)
    ])
    error_message = "All auth flows must be valid Cognito authentication flows."
  }
}

variable "cognito_allowed_oauth_flows" {
  description = "List of allowed OAuth flows for Cognito"
  type        = list(string)
  default     = ["code", "implicit"]
  validation {
    condition = alltrue([
      for flow in var.cognito_allowed_oauth_flows : contains(["code", "implicit", "client_credentials"], flow)
    ])
    error_message = "All OAuth flows must be valid: code, implicit, client_credentials."
  }
}

variable "cognito_allowed_oauth_scopes" {
  description = "List of allowed OAuth scopes for Cognito"
  type        = list(string)
  default     = ["email", "openid", "profile"]
  validation {
    condition = alltrue([
      for scope in var.cognito_allowed_oauth_scopes : contains([
        "phone", "email", "openid", "profile", "aws.cognito.signin.user.admin"
      ], scope)
    ])
    error_message = "All OAuth scopes must be valid Cognito scopes."
  }
}

variable "cognito_callback_urls" {
  description = "List of allowed callback URLs for OAuth"
  type        = list(string)
  default     = ["http://localhost:3000/auth/callback", "https://dev.placeholder.mx/auth/callback"]
  validation {
    condition = alltrue([
      for url in var.cognito_callback_urls : can(regex("^https?://", url))
    ])
    error_message = "All callback URLs must be valid HTTP or HTTPS URLs."
  }
}

variable "cognito_logout_urls" {
  description = "List of allowed logout URLs for OAuth"
  type        = list(string)
  default     = ["http://localhost:3000/auth/logout", "https://dev.placeholder.mx/auth/logout"]
  validation {
    condition = alltrue([
      for url in var.cognito_logout_urls : can(regex("^https?://", url))
    ])
    error_message = "All logout URLs must be valid HTTP or HTTPS URLs."
  }
}

variable "cognito_access_token_validity" {
  description = "Access token validity in hours"
  type        = number
  default     = 1
  validation {
    condition     = var.cognito_access_token_validity >= 1 && var.cognito_access_token_validity <= 24
    error_message = "Access token validity must be between 1 and 24 hours."
  }
}

variable "cognito_id_token_validity" {
  description = "ID token validity in hours"
  type        = number
  default     = 1
  validation {
    condition     = var.cognito_id_token_validity >= 1 && var.cognito_id_token_validity <= 24
    error_message = "ID token validity must be between 1 and 24 hours."
  }
}

variable "cognito_refresh_token_validity" {
  description = "Refresh token validity in days"
  type        = number
  default     = 7
  validation {
    condition     = var.cognito_refresh_token_validity >= 1 && var.cognito_refresh_token_validity <= 3650
    error_message = "Refresh token validity must be between 1 and 3650 days."
  }
}

variable "cognito_allow_unauthenticated_identities" {
  description = "Whether to allow unauthenticated identities in Cognito identity pool"
  type        = bool
  default     = true
}

# === S3 CONFIGURATION ===

variable "s3_enable_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = false
}

variable "s3_enable_lifecycle_policy" {
  description = "Enable S3 lifecycle policy for cost optimization"
  type        = bool
  default     = true
}

variable "s3_enable_intelligent_tiering" {
  description = "Enable S3 intelligent tiering for automatic cost optimization"
  type        = bool
  default     = false
}

variable "s3_enable_object_lock" {
  description = "Enable S3 object lock for compliance and data protection"
  type        = bool
  default     = false
}

variable "s3_lifecycle_transition_ia_days" {
  description = "Number of days after which objects transition to IA storage class"
  type        = number
  default     = 7
  validation {
    condition     = var.s3_lifecycle_transition_ia_days >= 1
    error_message = "IA transition days must be at least 1."
  }
}

variable "s3_lifecycle_transition_glacier_days" {
  description = "Number of days after which objects transition to Glacier storage class"
  type        = number
  default     = 30
  validation {
    condition     = var.s3_lifecycle_transition_glacier_days >= 1
    error_message = "Glacier transition days must be at least 1."
  }
}

variable "s3_noncurrent_version_expiration_days" {
  description = "Number of days after which noncurrent versions expire"
  type        = number
  default     = 30
  validation {
    condition     = var.s3_noncurrent_version_expiration_days >= 1
    error_message = "Noncurrent version expiration days must be at least 1."
  }
}

variable "s3_content_bucket_prefix" {
  description = "Prefix for S3 content bucket naming"
  type        = string
  default     = "inversiva-dev-content"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.s3_content_bucket_prefix))
    error_message = "S3 bucket prefix must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "s3_presigned_url_expiration_seconds" {
  description = "Expiration time for S3 presigned URLs in seconds"
  type        = number
  default     = 300
  validation {
    condition     = var.s3_presigned_url_expiration_seconds >= 1 && var.s3_presigned_url_expiration_seconds <= 604800
    error_message = "Presigned URL expiration must be between 1 second and 7 days (604800 seconds)."
  }
}

# === CLOUDFRONT CONFIGURATION ===

variable "cloudfront_price_class" {
  description = "CloudFront distribution price class"
  type        = string
  default     = "PriceClass_100"
  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.cloudfront_price_class)
    error_message = "Price class must be one of: PriceClass_All, PriceClass_200, PriceClass_100."
  }
}

variable "cloudfront_enable_ipv6" {
  description = "Enable IPv6 for CloudFront distribution"
  type        = bool
  default     = false
}

variable "cloudfront_enable_monitoring" {
  description = "Enable additional monitoring for CloudFront distribution"
  type        = bool
  default     = false
}

variable "cloudfront_content_security_policy" {
  description = "Content Security Policy header for CloudFront"
  type        = string
  default     = "default-src 'self' 'unsafe-inline' 'unsafe-eval'; script-src 'self' 'unsafe-inline' 'unsafe-eval' localhost:*; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https: localhost:*; frame-ancestors 'none';"
}

variable "cloudfront_error_caching_min_ttl" {
  description = "Minimum TTL for error caching in CloudFront"
  type        = number
  default     = 300
  validation {
    condition     = var.cloudfront_error_caching_min_ttl >= 0
    error_message = "Error caching min TTL must be non-negative."
  }
}

variable "cloudfront_logging_include_cookies" {
  description = "Include cookies in CloudFront access logs"
  type        = bool
  default     = false
}

# === ROUTE53 CONFIGURATION ===

variable "route53_create_hosted_zone" {
  description = "Whether to create a new Route53 hosted zone"
  type        = bool
  default     = false
}

variable "route53_enable_health_check" {
  description = "Enable Route53 health checks"
  type        = bool
  default     = false
}

variable "route53_enable_ipv6" {
  description = "Enable IPv6 AAAA records in Route53"
  type        = bool
  default     = false
}

variable "route53_health_check_path" {
  description = "Path for Route53 health check"
  type        = string
  default     = "/"
  validation {
    condition     = can(regex("^/", var.route53_health_check_path))
    error_message = "Health check path must start with '/'."
  }
}

variable "route53_health_check_failure_threshold" {
  description = "Number of consecutive failures before marking unhealthy"
  type        = number
  default     = 3
  validation {
    condition     = var.route53_health_check_failure_threshold >= 1 && var.route53_health_check_failure_threshold <= 10
    error_message = "Health check failure threshold must be between 1 and 10."
  }
}

variable "route53_health_check_request_interval" {
  description = "Request interval for health checks in seconds"
  type        = number
  default     = 30
  validation {
    condition     = contains([10, 30], var.route53_health_check_request_interval)
    error_message = "Health check request interval must be either 10 or 30 seconds."
  }
}

# === CORS CONFIGURATION ===

variable "cors_allow_credentials" {
  description = "Allow credentials in CORS requests"
  type        = bool
  default     = false
}

variable "cors_allow_headers" {
  description = "List of allowed headers for CORS"
  type        = list(string)
  default     = ["Accept", "Accept-Language", "Content-Language", "Content-Type", "Authorization"]
}

variable "cors_allow_methods" {
  description = "List of allowed HTTP methods for CORS"
  type        = list(string)
  default     = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
  validation {
    condition = alltrue([
      for method in var.cors_allow_methods : contains([
        "GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"
      ], method)
    ])
    error_message = "All CORS methods must be valid HTTP methods."
  }
}

variable "cors_allow_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = ["http://localhost:3000", "https://dev.placeholder.mx"]
  validation {
    condition = alltrue([
      for origin in var.cors_allow_origins : can(regex("^https?://", origin))
    ])
    error_message = "All CORS origins must be valid HTTP or HTTPS URLs."
  }
}

variable "cors_max_age_seconds" {
  description = "Maximum age for CORS preflight requests in seconds"
  type        = number
  default     = 86400
  validation {
    condition     = var.cors_max_age_seconds >= 0 && var.cors_max_age_seconds <= 86400
    error_message = "CORS max age must be between 0 and 86400 seconds (24 hours)."
  }
}