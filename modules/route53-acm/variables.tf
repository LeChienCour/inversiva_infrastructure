# Route 53 and ACM Certificate Module Variables

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

# Domain Configuration
variable "domain_name" {
  description = "Root domain name (e.g., example.com)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9.-]+\\.[a-z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid domain format."
  }
}

variable "subdomain" {
  description = "Single subdomain prefix (e.g., 'www' for www.example.com). If null, uses root domain. Use 'subdomains' for multiple subdomains."
  type        = string
  default     = null
  validation {
    condition     = var.subdomain == null || can(regex("^[a-z0-9-]+$", var.subdomain))
    error_message = "Subdomain must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "subdomains" {
  description = "List of subdomain prefixes (e.g., ['www', 'api', 'app'] for www.example.com, api.example.com, app.example.com). Cannot be used with 'subdomain'."
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for subdomain in var.subdomains : can(regex("^[a-z0-9-]+$", subdomain))
    ])
    error_message = "All subdomains must contain only lowercase letters, numbers, and hyphens."
  }
  validation {
    condition     = length(var.subdomains) <= 10
    error_message = "Maximum of 10 subdomains allowed per certificate."
  }
  validation {
    condition     = !(var.subdomain != null && length(var.subdomains) > 0)
    error_message = "Cannot use both 'subdomain' and 'subdomains' variables. Use one or the other."
  }
}

variable "include_root_domain" {
  description = "Whether to include the root domain in the certificate when using multiple subdomains"
  type        = bool
  default     = true
}

variable "primary_subdomain" {
  description = "Primary subdomain to use for health checks and main DNS record when using multiple subdomains. If null, uses the first subdomain in the list."
  type        = string
  default     = null
  validation {
    condition     = var.primary_subdomain == null || can(regex("^[a-z0-9-]+$", var.primary_subdomain))
    error_message = "Primary subdomain must contain only lowercase letters, numbers, and hyphens."
  }
}

# Route 53 Configuration
variable "create_hosted_zone" {
  description = "Whether to create a new Route 53 hosted zone or use an existing one (adds $0.50/month cost)"
  type        = bool
  default     = true
}

variable "enable_ipv6" {
  description = "Enable IPv6 AAAA records for the domain"
  type        = bool
  default     = false
}

# CloudFront Integration
variable "cloudfront_distribution_domain_name" {
  description = "Domain name of the CloudFront distribution to point the domain to"
  type        = string
  default     = null
}

variable "cloudfront_distribution_hosted_zone_id" {
  description = "Hosted zone ID of the CloudFront distribution"
  type        = string
  default     = null
}

# Health Check Configuration
variable "enable_health_check" {
  description = "Enable Route 53 health check for the domain (adds $0.50/month cost)"
  type        = bool
  default     = false
}

variable "health_check_path" {
  description = "Path to check for health monitoring"
  type        = string
  default     = "/"
}

variable "health_check_failure_threshold" {
  description = "Number of consecutive failures before marking as unhealthy"
  type        = number
  default     = 3
  validation {
    condition     = var.health_check_failure_threshold >= 1 && var.health_check_failure_threshold <= 10
    error_message = "Health check failure threshold must be between 1 and 10."
  }
}

variable "health_check_request_interval" {
  description = "Interval between health checks in seconds (30 or 10)"
  type        = number
  default     = 30
  validation {
    condition     = contains([10, 30], var.health_check_request_interval)
    error_message = "Health check request interval must be either 10 or 30 seconds."
  }
}

# General Configuration
variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Cost Optimization Configuration
variable "cost_optimization_enabled" {
  description = "Enable cost optimization features based on environment"
  type        = bool
  default     = true
}

variable "dev_cost_optimizations" {
  description = "Cost optimization settings for development environments"
  type = object({
    create_hosted_zone  = bool
    enable_health_check = bool
    enable_ipv6         = bool
  })
  default = {
    create_hosted_zone  = false # Use existing zone to save $0.50/month
    enable_health_check = false # Disable health checks to save $0.50/month
    enable_ipv6         = false # Disable IPv6 if not needed
  }
}