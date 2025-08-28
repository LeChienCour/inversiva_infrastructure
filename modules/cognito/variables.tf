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

variable "password_policy" {
  description = "Password policy configuration for the user pool"
  type = object({
    minimum_length                   = number
    require_lowercase                = bool
    require_numbers                  = bool
    require_symbols                  = bool
    require_uppercase                = bool
    temporary_password_validity_days = number
  })
  default = {
    minimum_length                   = 8
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = false
    require_uppercase                = true
    temporary_password_validity_days = 7
  }
}

variable "mfa_configuration" {
  description = "MFA configuration for the user pool"
  type        = string
  default     = "OPTIONAL"
  validation {
    condition     = contains(["OFF", "ON", "OPTIONAL"], var.mfa_configuration)
    error_message = "MFA configuration must be one of: OFF, ON, OPTIONAL."
  }
}

variable "enable_software_token_mfa" {
  description = "Enable software token (TOTP) MFA method"
  type        = bool
  default     = true
}

variable "explicit_auth_flows" {
  description = "List of authentication flows for the user pool client"
  type        = list(string)
  default = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH"
  ]
}

variable "allowed_oauth_flows" {
  description = "List of allowed OAuth flows"
  type        = list(string)
  default     = ["code", "implicit"]
}

variable "allowed_oauth_scopes" {
  description = "List of allowed OAuth scopes"
  type        = list(string)
  default     = ["email", "openid", "profile"]
}

variable "callback_urls" {
  description = "List of allowed callback URLs for OAuth"
  type        = list(string)
  default     = ["http://localhost:3000/auth/callback"]
}

variable "logout_urls" {
  description = "List of allowed logout URLs for OAuth"
  type        = list(string)
  default     = ["http://localhost:3000/auth/logout"]
}

variable "token_validity" {
  description = "Token validity configuration"
  type = object({
    access_token  = number
    id_token      = number
    refresh_token = number
  })
  default = {
    access_token  = 1
    id_token      = 1
    refresh_token = 30
  }
}

variable "allow_unauthenticated_identities" {
  description = "Whether to allow unauthenticated identities in the identity pool"
  type        = bool
  default     = false
}

variable "content_bucket_arn" {
  description = "ARN of the S3 content bucket for IAM policy configuration"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}