# Variables for bootstrap infrastructure

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "terraform-nextjs-infrastructure"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "terraform-nextjs-infrastructure"
    ManagedBy = "terraform"
    Purpose   = "bootstrap"
  }
}