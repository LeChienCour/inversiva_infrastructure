# CloudFront Distribution Module Variables

variable "project_name" {
  description = "Name of the project, used for resource naming"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

# S3 Origin Configuration
variable "s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket to use as origin"
  type        = string
}

variable "origin_access_control_id" {
  description = "ID of the CloudFront Origin Access Control for S3 bucket"
  type        = string
}

variable "use_s3_website_endpoint" {
  description = "Whether to use S3 website endpoint instead of REST API endpoint"
  type        = bool
  default     = false
}

# Domain and Certificate Configuration
variable "domain_name" {
  description = "Custom domain name for the CloudFront distribution"
  type        = string
  default     = null
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for custom domain (must be in us-east-1)"
  type        = string
  default     = null
  validation {
    condition = var.acm_certificate_arn == null || can(regex("^arn:aws:acm:us-east-1:[0-9]{12}:certificate/[a-f0-9-]+$", var.acm_certificate_arn))
    error_message = "ACM certificate ARN must be valid and in us-east-1 region."
  }
}

variable "minimum_tls_version" {
  description = "Minimum TLS version for HTTPS connections"
  type        = string
  default     = "TLSv1.2_2021"
  validation {
    condition     = contains(["SSLv3", "TLSv1", "TLSv1_2016", "TLSv1.1_2016", "TLSv1.2_2018", "TLSv1.2_2019", "TLSv1.2_2021"], var.minimum_tls_version)
    error_message = "Minimum TLS version must be a valid CloudFront TLS version."
  }
}

# CloudFront Configuration
variable "default_root_object" {
  description = "Default root object for the distribution"
  type        = string
  default     = "index.html"
}

variable "price_class" {
  description = "Price class for the distribution (PriceClass_100, PriceClass_200, PriceClass_All)"
  type        = string
  default     = null
  validation {
    condition = var.price_class == null || contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "Price class must be one of: PriceClass_100, PriceClass_200, PriceClass_All."
  }
}

variable "enable_ipv6" {
  description = "Enable IPv6 support for the distribution (disable for cost savings if not needed)"
  type        = bool
  default     = false  # Changed to false for cost optimization
}

variable "web_acl_id" {
  description = "AWS WAF web ACL ID to associate with the distribution"
  type        = string
  default     = null
}

# Geographic Restrictions
variable "geo_restriction_type" {
  description = "Type of geographic restriction (none, whitelist, blacklist)"
  type        = string
  default     = "none"
  validation {
    condition     = contains(["none", "whitelist", "blacklist"], var.geo_restriction_type)
    error_message = "Geo restriction type must be one of: none, whitelist, blacklist."
  }
}

variable "geo_restriction_locations" {
  description = "List of country codes for geographic restrictions"
  type        = list(string)
  default     = []
}

# Security Headers Configuration
variable "content_security_policy" {
  description = "Content Security Policy header value"
  type        = string
  default     = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:; frame-ancestors 'none';"
}

variable "custom_headers" {
  description = "List of custom headers to add to responses"
  type = list(object({
    header   = string
    value    = string
    override = bool
  }))
  default = []
}

# CORS Configuration
variable "cors_allow_credentials" {
  description = "Whether to allow credentials in CORS requests"
  type        = bool
  default     = false
}

variable "cors_allow_headers" {
  description = "List of headers allowed in CORS requests"
  type        = list(string)
  default     = ["Accept", "Accept-Language", "Content-Language", "Content-Type", "Authorization"]
}

variable "cors_allow_methods" {
  description = "List of HTTP methods allowed in CORS requests"
  type        = list(string)
  default     = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
}

variable "cors_allow_origins" {
  description = "List of origins allowed in CORS requests"
  type        = list(string)
  default     = ["*"]
}

variable "cors_expose_headers" {
  description = "List of headers exposed in CORS responses"
  type        = list(string)
  default     = []
}

variable "cors_max_age_seconds" {
  description = "Maximum age in seconds for CORS preflight requests"
  type        = number
  default     = 86400
  validation {
    condition     = var.cors_max_age_seconds >= 0 && var.cors_max_age_seconds <= 86400
    error_message = "CORS max age must be between 0 and 86400 seconds."
  }
}

# Error Handling Configuration
variable "custom_error_responses" {
  description = "List of custom error response configurations"
  type = list(object({
    error_code            = number
    response_code         = number
    response_page_path    = string
    error_caching_min_ttl = number
  }))
  default = [
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
}

# Logging Configuration
variable "logging_bucket" {
  description = "S3 bucket name for CloudFront access logs"
  type        = string
  default     = null
}

variable "logging_include_cookies" {
  description = "Whether to include cookies in access logs"
  type        = bool
  default     = false
}

# Monitoring Configuration
variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring and alarms (additional cost)"
  type        = bool
  default     = false
}

variable "error_rate_threshold" {
  description = "Threshold for 4xx error rate alarm (percentage)"
  type        = number
  default     = 5.0
  validation {
    condition     = var.error_rate_threshold >= 0 && var.error_rate_threshold <= 100
    error_message = "Error rate threshold must be between 0 and 100."
  }
}

variable "origin_latency_threshold" {
  description = "Threshold for origin latency alarm (milliseconds)"
  type        = number
  default     = 5000
  validation {
    condition     = var.origin_latency_threshold > 0
    error_message = "Origin latency threshold must be greater than 0."
  }
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarms trigger"
  type        = list(string)
  default     = []
}

# General Configuration
variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}