# Development Environment - Monitoring Configuration

# Include the root terragrunt configuration
include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

# Include environment-specific configuration
include "env" {
  path = "../terragrunt.hcl"
  expose = true
}

terraform {
  source = "../../../modules/monitoring"
}

# Dependencies - monitoring needs other infrastructure to be deployed first
dependencies {
  paths = ["../s3-website", "../s3-content", "../cloudfront"]
}

dependency "s3_website" {
  config_path = "../s3-website"
  mock_outputs = {
    bucket_name = "mock-website-bucket"
    bucket_arn  = "arn:aws:s3:::mock-website-bucket"
  }
}

dependency "s3_content" {
  config_path = "../s3-content"
  mock_outputs = {
    bucket_name = "mock-content-bucket"
    bucket_arn  = "arn:aws:s3:::mock-content-bucket"
  }
}

dependency "cloudfront" {
  config_path = "../cloudfront"
  mock_outputs = {
    distribution_id = "MOCK123456789"
  }
}

dependency "cognito" {
  config_path = "../cognito"
  mock_outputs = {
    user_pool_id = "us-east-1_MOCK123456"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  project_name               = include.env.locals.project_name
  environment               = include.env.locals.environment
  cloudfront_distribution_id = dependency.cloudfront.outputs.distribution_id
  website_bucket_name       = dependency.s3_website.outputs.bucket_name
  website_bucket_arn        = dependency.s3_website.outputs.bucket_arn
  content_bucket_name       = dependency.s3_content.outputs.bucket_name
  content_bucket_arn        = dependency.s3_content.outputs.bucket_arn
  cognito_user_pool_id      = dependency.cognito.outputs.user_pool_id
  
  # Ultra-low cost development settings
  alert_email_addresses      = ["dev-team@example.com"]
  monthly_budget_limit       = "5"    # Very low budget for dev
  enable_cloudtrail         = false   # Disabled to save costs
  log_retention_days        = 1       # Minimum retention
  enable_detailed_monitoring = false  # Disabled
  enable_dashboard          = false   # Disabled to save ~$3/month
  enable_performance_alarms = false   # Only essential alarms
  enable_cost_alarms        = true    # Keep cost monitoring
  enable_sns_alerts         = true    # Keep alerts for cost overruns
  cost_alarm_threshold      = "1"     # Alert if daily cost > $1
}