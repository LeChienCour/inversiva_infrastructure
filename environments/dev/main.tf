# Development Environment - Main Terraform Configuration
# This file instantiates all required modules for the development environment

# Terraform version and provider constraints are defined in versions.tf

# Provider configurations are now in provider.tf

# Local values for common configuration
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    CreatedBy   = "terraform"
    CostCenter  = var.cost_center
    Owner       = var.owner
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
      mfa_configuration    = var.cognito_mfa_configuration
      explicit_auth_flows  = var.cognito_explicit_auth_flows
      allowed_oauth_flows  = var.cognito_allowed_oauth_flows
      allowed_oauth_scopes = var.cognito_allowed_oauth_scopes
      callback_urls        = var.cognito_callback_urls
      logout_urls          = var.cognito_logout_urls
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
      error_caching_min_ttl   = var.cloudfront_error_caching_min_ttl
      logging_include_cookies = var.cloudfront_logging_include_cookies
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
      max_age_seconds   = var.cors_max_age_seconds
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
  enable_health_check            = local.environment_config.route53_config.enable_health_check
  enable_ipv6                    = local.environment_config.route53_config.enable_ipv6
  health_check_path              = local.environment_config.route53_config.health_check_path
  health_check_failure_threshold = local.environment_config.route53_config.health_check_failure_threshold
  health_check_request_interval  = local.environment_config.route53_config.health_check_request_interval

  # Override cost optimization to allow hosted zone creation in dev
  cost_optimization_enabled = false

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

  # Placeholder ARN - will be updated by separate resource
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

  alert_email_addresses      = []
  monthly_budget_limit       = "10"
  enable_cloudtrail          = false  # Disabled for dev to save costs
  enable_dashboard           = false  # Disabled for dev to save costs
  enable_performance_alarms  = true
  enable_cost_alarms         = true

  depends_on = [module.cloudfront, module.s3_website, module.s3_content, module.cognito]
}

# DNS Records for CloudFront Distribution
# These are created separately to avoid circular dependencies
resource "aws_route53_record" "domain_a_record" {
  zone_id = module.route53_acm.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.cloudfront.distribution_domain_name
    zone_id                = module.cloudfront.distribution_hosted_zone_id
    evaluate_target_health = false
  }

  depends_on = [module.cloudfront, module.route53_acm]
}

# IPv6 AAAA record (if enabled)
resource "aws_route53_record" "domain_aaaa_record" {
  count = local.environment_config.route53_config.enable_ipv6 ? 1 : 0

  zone_id = module.route53_acm.hosted_zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = module.cloudfront.distribution_domain_name
    zone_id                = module.cloudfront.distribution_hosted_zone_id
    evaluate_target_health = false
  }

  depends_on = [module.cloudfront, module.route53_acm]
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Updated S3 bucket policy with deployment access and correct CloudFront ARN
resource "aws_s3_bucket_policy" "website_deployment" {
  bucket = module.s3_website.bucket_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${module.s3_website.bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = module.cloudfront.distribution_arn
          }
        }
      },
      {
        Sid    = "AllowDeploymentAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          module.s3_website.bucket_arn,
          "${module.s3_website.bucket_arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "true"
          }
        }
      },
      {
        Sid       = "DenyInsecureConnections"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          module.s3_website.bucket_arn,
          "${module.s3_website.bucket_arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "DenyUnencryptedObjectUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${module.s3_website.bucket_arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "AES256"
          }
        }
      },
      {
        Sid       = "DenyPublicReadACL"
        Effect    = "Deny"
        Principal = "*"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${module.s3_website.bucket_arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = [
              "public-read",
              "public-read-write",
              "authenticated-read"
            ]
          }
        }
      }
    ]
  })

  depends_on = [module.cloudfront, module.s3_website]
}