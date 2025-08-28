# Variables for Monitoring Module

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be either 'dev' or 'prod'."
  }
}

variable "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for monitoring"
  type        = string
}

variable "website_bucket_name" {
  description = "Name of the S3 website bucket"
  type        = string
}

variable "website_bucket_arn" {
  description = "ARN of the S3 website bucket"
  type        = string
}

variable "content_bucket_name" {
  description = "Name of the S3 content bucket"
  type        = string
}

variable "content_bucket_arn" {
  description = "ARN of the S3 content bucket"
  type        = string
}

variable "alert_email_addresses" {
  description = "List of email addresses to receive alerts"
  type        = list(string)
  default     = ["cheval.diego@gmail.com"]
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = string
  default     = "10"  # Reduced default budget
}

variable "enable_cloudtrail" {
  description = "Enable CloudTrail for security monitoring"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch Logs retention period."
  }
}

variable "cognito_user_pool_id" {
  description = "Cognito User Pool ID for monitoring"
  type        = string
  default     = ""
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed monitoring with additional metrics"
  type        = bool
  default     = false
}

variable "enable_dashboard" {
  description = "Enable CloudWatch dashboard (costs ~$3/month per dashboard)"
  type        = bool
  default     = false
}

variable "enable_performance_alarms" {
  description = "Enable performance monitoring alarms"
  type        = bool
  default     = true
}

variable "enable_cost_alarms" {
  description = "Enable cost monitoring alarms"
  type        = bool
  default     = true
}

variable "enable_sns_alerts" {
  description = "Enable SNS email alerts (disable to save costs)"
  type        = bool
  default     = true
}

variable "cost_alarm_threshold" {
  description = "Daily cost threshold for cost alarm in USD"
  type        = string
  default     = "2"  # Alert if daily costs exceed $2
}