# Production Environment - Main Terraform Configuration
# This file instantiates all required modules for the production environment

# Terraform version and provider constraints are defined in versions.tf

# Provider configurations are now in provider.tf

# Local values for common configuration
locals {
  common_tags = {
    Project          = var.project_name
    Environment      = var.environment
    ManagedBy        = "terraform"
    CreatedBy        = "terraform"
    CostCenter       = var.cost_center
    Owner            = var.owner
    AutoShutdown     = var.auto_shutdown
    Compliance       = var.compliance
    DataClassification = var.data_classification
    BackupRequired   = var.backup_required
    MonitoringLevel  = var.monitoring_level
  }

  # Environment-specific configuration
  environment_config = {
    environment = var.environment
    domain_name = var.domain_name
    root_domain = var.root_domain

    cognito_config = {
      password_policy = {
        minimum_length                   = var.cognito_min_password_length
        require_lowercase                = var.cognito_require_lowercase
        require_numbers                  = var.cognito_require_numbers
        require_symbols                  = var.cognito_require_symbols
        require_uppercase                = var.cognito_require_uppercase
        temporary_password_validity_days = var.cognito_temp_password_validity
      }
      mfa_configuration                = var.cognito_mfa_configuration
      explicit_auth_flows              = var.cognito_explicit_auth_flows
      allowed_oauth_flows              = var.cognito_allowed_oauth_flows
      allowed_oauth_scopes             = var.cognito_allowed_oauth_scopes
      callback_urls                    = var.cognito_callback_urls
      logout_urls                      = var.cognito_logout_urls
      token_validity = {
        access_token  = var.cognito_access_token_validity
        id_token      = var.cognito_id_token_validity
        refresh_token = var.cognito_refresh_token_validity
      }
      allow_unauthenticated_identities = var.cognito_allow_unauthenticated_identities
    }

    s3_config = {
      enable_versioning                  = var.s3_enable_versioning
      enable_lifecycle_policy            = var.s3_enable_lifecycle_policy
      enable_intelligent_tiering         = var.s3_enable_intelligent_tiering
      enable_object_lock                 = var.s3_enable_object_lock
      lifecycle_transition_ia_days       = var.s3_lifecycle_transition_ia_days
      lifecycle_transition_glacier_days  = var.s3_lifecycle_transition_glacier_days
      noncurrent_version_expiration_days = var.s3_noncurrent_version_expiration_days
      content_bucket_prefix              = var.s3_content_bucket_prefix
      presigned_url_expiration_seconds   = var.s3_presigned_url_expiration_seconds
    }

    cloudfront_config = {
      price_class             = var.cloudfront_price_class
      enable_ipv6             = var.cloudfront_enable_ipv6
      enable_monitoring       = var.cloudfront_enable_monitoring
      content_security_policy = var.cloudfront_content_security_policy
      logging_include_cookies = var.cloudfront_logging_include_cookies
      geo_restriction_type    = var.cloudfront_geo_restriction_type
    }

    route53_config = {
      create_hosted_zone             = var.route53_create_hosted_zone
      enable_health_check            = var.route53_enable_health_check
      enable_ipv6                    = var.route53_enable_ipv6
      health_check_path              = var.route53_health_check_path
      health_check_failure_threshold = var.route53_health_check_failure_threshold
      health_check_request_interval  = var.route53_health_check_request_interval
    }

    cors_config = {
      allow_credentials = var.cors_allow_credentials
      allow_headers     = var.cors_allow_headers
      allow_methods     = var.cors_allow_methods
      allow_origins     = var.cors_allow_origins
      expose_headers    = var.cors_expose_headers
      max_age_seconds   = var.cors_max_age_seconds
    }

    monitoring_config = {
      enable_cloudwatch_alarms = var.monitoring_enable_cloudwatch_alarms
      enable_cost_alerts       = var.monitoring_enable_cost_alerts
      enable_security_alerts   = var.monitoring_enable_security_alerts
      log_retention_days       = var.monitoring_log_retention_days
      alert_email              = var.monitoring_alert_email
      monthly_cost_threshold   = var.monitoring_monthly_cost_threshold
      daily_cost_threshold     = var.monitoring_daily_cost_threshold
    }

    backup_config = {
      enable_cross_region_replication   = var.backup_enable_cross_region_replication
      backup_region                     = var.backup_region
      retention_days                    = var.backup_retention_days
      enable_point_in_time_recovery     = var.backup_enable_point_in_time_recovery
    }
  }
}

# Route53 and ACM Certificate Module
module "route53_acm" {
  source = "../../modules/route53-acm"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  project_name = var.project_name
  environment  = var.environment
  domain_name  = var.domain_name

  create_hosted_zone             = local.environment_config.route53_config.create_hosted_zone
  enable_health_check            = false
  enable_ipv6                    = local.environment_config.route53_config.enable_ipv6
  health_check_path              = local.environment_config.route53_config.health_check_path
  health_check_failure_threshold = local.environment_config.route53_config.health_check_failure_threshold
  health_check_request_interval  = local.environment_config.route53_config.health_check_request_interval

  tags = local.common_tags
}

# Cognito Authentication Module
module "cognito" {
  source = "../../modules/cognito"

  project_name = var.project_name
  environment  = var.environment

  password_policy                  = local.environment_config.cognito_config.password_policy
  mfa_configuration                = local.environment_config.cognito_config.mfa_configuration
  explicit_auth_flows              = local.environment_config.cognito_config.explicit_auth_flows
  allowed_oauth_flows              = local.environment_config.cognito_config.allowed_oauth_flows
  allowed_oauth_scopes             = local.environment_config.cognito_config.allowed_oauth_scopes
  callback_urls                    = local.environment_config.cognito_config.callback_urls
  logout_urls                      = local.environment_config.cognito_config.logout_urls
  token_validity                   = local.environment_config.cognito_config.token_validity
  allow_unauthenticated_identities = local.environment_config.cognito_config.allow_unauthenticated_identities

  content_bucket_arn = module.s3_content.bucket_arn

  tags = local.common_tags

  depends_on = [module.s3_content]
}

# S3 Website Hosting Module
module "s3_website" {
  source = "../../modules/s3-website"

  project_name = var.project_name
  environment  = var.environment

  # Placeholder ARN - will be updated after CloudFront distribution is created
  cloudfront_distribution_arn = "arn:aws:cloudfront::123456789012:distribution/PLACEHOLDER"

  enable_versioning          = local.environment_config.s3_config.enable_versioning
  enable_lifecycle_policy    = local.environment_config.s3_config.enable_lifecycle_policy
  enable_intelligent_tiering = local.environment_config.s3_config.enable_intelligent_tiering
  enable_object_lock         = local.environment_config.s3_config.enable_object_lock

  tags = local.common_tags
}

# S3 Content Storage Module
module "s3_content" {
  source = "../../modules/s3-content"

  bucket_name_prefix                           = local.environment_config.s3_config.content_bucket_prefix
  environment                                  = var.environment
  cognito_user_pool_arn                        = "" # Will be updated after cognito is created
  enable_versioning                            = local.environment_config.s3_config.enable_versioning
  enable_lifecycle_policy                      = local.environment_config.s3_config.enable_lifecycle_policy
  lifecycle_transition_ia_days                 = local.environment_config.s3_config.lifecycle_transition_ia_days
  lifecycle_transition_glacier_days            = local.environment_config.s3_config.lifecycle_transition_glacier_days
  lifecycle_noncurrent_version_expiration_days = local.environment_config.s3_config.noncurrent_version_expiration_days
  cors_allowed_origins                         = local.environment_config.cors_config.allow_origins
  presigned_url_expiration_seconds             = local.environment_config.s3_config.presigned_url_expiration_seconds

  tags = local.common_tags
}

# CloudFront Distribution Module
module "cloudfront" {
  source = "../../modules/cloudfront"

  project_name = var.project_name
  environment  = var.environment
  domain_name  = var.domain_name

  s3_bucket_domain_name    = module.s3_website.bucket_domain_name
  origin_access_control_id = module.s3_website.origin_access_control_id
  acm_certificate_arn      = module.route53_acm.certificate_arn

  price_class             = local.environment_config.cloudfront_config.price_class
  enable_ipv6             = local.environment_config.cloudfront_config.enable_ipv6
  enable_monitoring       = local.environment_config.cloudfront_config.enable_monitoring
  content_security_policy = local.environment_config.cloudfront_config.content_security_policy
  logging_include_cookies = local.environment_config.cloudfront_config.logging_include_cookies
  geo_restriction_type    = local.environment_config.cloudfront_config.geo_restriction_type

  tags = local.common_tags

  depends_on = [module.s3_website, module.route53_acm]
}

# Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"

  project_name = var.project_name
  environment  = var.environment

  cloudfront_distribution_id = module.cloudfront.distribution_id
  website_bucket_name        = module.s3_website.bucket_name
  website_bucket_arn         = module.s3_website.bucket_arn
  content_bucket_name        = module.s3_content.bucket_name
  content_bucket_arn         = module.s3_content.bucket_arn
  cognito_user_pool_id       = module.cognito.user_pool_id

  alert_email_addresses    = [local.environment_config.monitoring_config.alert_email]
  monthly_budget_limit     = tostring(local.environment_config.monitoring_config.monthly_cost_threshold)
  log_retention_days       = local.environment_config.monitoring_config.log_retention_days
  enable_cost_alarms       = local.environment_config.monitoring_config.enable_cost_alerts
  enable_performance_alarms = local.environment_config.monitoring_config.enable_cloudwatch_alarms
  cost_alarm_threshold     = tostring(local.environment_config.monitoring_config.daily_cost_threshold)

  depends_on = [module.cloudfront, module.s3_website, module.s3_content, module.cognito]
}