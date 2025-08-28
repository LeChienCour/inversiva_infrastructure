# S3 Content Storage Module Variables

variable "bucket_name_prefix" {
  description = "Prefix for the S3 bucket name. Will be combined with environment and random suffix"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.bucket_name_prefix))
    error_message = "Bucket name prefix must contain only lowercase letters, numbers, and hyphens, and cannot start or end with a hyphen."
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

variable "cognito_user_pool_arn" {
  description = "ARN of the Cognito User Pool for user authentication"
  type        = string
}

variable "enable_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "enable_lifecycle_policy" {
  description = "Enable lifecycle policy for cost optimization"
  type        = bool
  default     = true
}

variable "lifecycle_transition_ia_days" {
  description = "Number of days after which objects transition to Standard-IA storage class (0 to disable)"
  type        = number
  default     = 30
  validation {
    condition     = var.lifecycle_transition_ia_days >= 0
    error_message = "Lifecycle transition to IA days must be 0 or greater."
  }
}

variable "lifecycle_transition_glacier_days" {
  description = "Number of days after which objects transition to Glacier storage class (0 to disable)"
  type        = number
  default     = 90
  validation {
    condition     = var.lifecycle_transition_glacier_days >= 0
    error_message = "Lifecycle transition to Glacier days must be 0 or greater."
  }
  validation {
    condition     = var.lifecycle_transition_glacier_days == 0 || var.lifecycle_transition_ia_days == 0 || var.lifecycle_transition_glacier_days > var.lifecycle_transition_ia_days
    error_message = "Glacier transition days must be greater than Standard-IA transition days when both are enabled."
  }
}

variable "lifecycle_noncurrent_version_expiration_days" {
  description = "Number of days after which noncurrent object versions are deleted"
  type        = number
  default     = 90
  validation {
    condition     = var.lifecycle_noncurrent_version_expiration_days > 0
    error_message = "Noncurrent version expiration days must be greater than 0."
  }
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS configuration"
  type        = list(string)
  default     = ["*"]
}

variable "presigned_url_expiration_seconds" {
  description = "Default expiration time for presigned URLs in seconds"
  type        = number
  default     = 900 # 15 minutes
  validation {
    condition     = var.presigned_url_expiration_seconds > 0 && var.presigned_url_expiration_seconds <= 604800
    error_message = "Presigned URL expiration must be between 1 second and 7 days (604800 seconds)."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}