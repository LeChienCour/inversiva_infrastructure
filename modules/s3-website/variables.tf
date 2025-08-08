# S3 Website Hosting Module Variables

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

variable "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution that will access this bucket"
  type        = string
  validation {
    condition     = can(regex("^arn:aws:cloudfront::[0-9]{12}:distribution/[A-Z0-9]+$", var.cloudfront_distribution_arn))
    error_message = "CloudFront distribution ARN must be a valid ARN format."
  }
}

variable "index_document" {
  description = "Name of the index document for the website"
  type        = string
  default     = "index.html"
}

variable "error_document" {
  description = "Name of the error document for the website"
  type        = string
  default     = "error.html"
}

variable "enable_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = false
}

variable "enable_lifecycle_policy" {
  description = "Enable S3 lifecycle policy for cost optimization"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "routing_rules" {
  description = "List of routing rules for the website configuration"
  type = list(object({
    condition = object({
      key_prefix_equals = string
    })
    redirect = object({
      replace_key_prefix_with = string
    })
  }))
  default = []
}

variable "notification_configurations" {
  description = "List of S3 bucket notification configurations"
  type = list(object({
    lambda_function_arn = string
    events              = list(string)
    filter_prefix       = optional(string)
    filter_suffix       = optional(string)
  }))
  default = []
}

# Security-related variables
variable "access_logging_bucket" {
  description = "S3 bucket name for access logging. If not provided, access logging will be disabled"
  type        = string
  default     = null
}

variable "enable_object_lock" {
  description = "Enable S3 object lock for compliance and data protection. Note: This automatically enables versioning"
  type        = bool
  default     = false
}

variable "object_lock_retention_days" {
  description = "Number of days to retain objects when object lock is enabled"
  type        = number
  default     = 30
  validation {
    condition     = var.object_lock_retention_days >= 1 && var.object_lock_retention_days <= 36500
    error_message = "Object lock retention days must be between 1 and 36500."
  }
}

variable "enable_intelligent_tiering" {
  description = "Enable S3 intelligent tiering for automatic cost optimization"
  type        = bool
  default     = false
}