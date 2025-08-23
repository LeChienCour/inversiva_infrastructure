# Route 53 and ACM Certificate Module
# This module creates a Route 53 hosted zone and ACM certificate with DNS validation

# Data source to get current AWS region
data "aws_region" "current" {}

# Data source to get current AWS caller identity
data "aws_caller_identity" "current" {}

# Random ID for unique resource naming
resource "random_id" "suffix" {
  byte_length = 4
}

# Local values for resource naming and configuration
locals {
  # Naming convention: {project}-{environment}-{service}-{random_suffix}
  naming_prefix = "${var.project_name}-${var.environment}"

  # Common tags applied to all resources
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      Module      = "route53-acm"
      ManagedBy   = "terraform"
    },
    var.tags
  )

  # Domain configuration
  root_domain = var.domain_name

  # Determine if using single subdomain or multiple subdomains
  using_multiple_subdomains = length(var.subdomains) > 0
  using_single_subdomain    = var.subdomain != null

  # Build list of all domains for the certificate
  all_subdomains = local.using_multiple_subdomains ? var.subdomains : (local.using_single_subdomain ? [var.subdomain] : [])

  # Full domain names for all subdomains
  subdomain_fqdns = [
    for subdomain in local.all_subdomains : "${subdomain}.${var.domain_name}"
  ]

  # Primary domain (used for main DNS record and health checks)
  primary_domain = local.using_multiple_subdomains ? (
    var.primary_subdomain != null ? "${var.primary_subdomain}.${var.domain_name}" : local.subdomain_fqdns[0]
    ) : (
    local.using_single_subdomain ? "${var.subdomain}.${var.domain_name}" : var.domain_name
  )

  # Certificate domain names
  certificate_domains = local.using_multiple_subdomains ? (
    var.include_root_domain ? concat([var.domain_name], local.subdomain_fqdns) : local.subdomain_fqdns
    ) : (
    local.using_single_subdomain ? [var.domain_name, "${var.subdomain}.${var.domain_name}"] : [var.domain_name]
  )

  # Legacy compatibility
  subdomain = local.primary_domain

  # Cost optimization logic
  is_dev_environment = var.environment == "dev"

  # Apply cost optimizations for dev environment if enabled
  effective_create_hosted_zone = var.cost_optimization_enabled && local.is_dev_environment ? var.dev_cost_optimizations.create_hosted_zone : var.create_hosted_zone

  effective_enable_health_check = var.cost_optimization_enabled && local.is_dev_environment ? var.dev_cost_optimizations.enable_health_check : var.enable_health_check

  effective_enable_ipv6 = var.cost_optimization_enabled && local.is_dev_environment ? var.dev_cost_optimizations.enable_ipv6 : var.enable_ipv6
}

# Route 53 Hosted Zone
resource "aws_route53_zone" "main" {
  count = local.effective_create_hosted_zone ? 1 : 0

  name          = var.domain_name
  comment       = "Hosted zone for ${var.project_name} ${var.environment} environment"
  force_destroy = var.environment != "prod" # Allow destruction for non-prod environments

  tags = merge(
    local.common_tags,
    {
      Name = "${local.naming_prefix}-hosted-zone"
    }
  )
}

# Data source for existing hosted zone (if not creating new one)
data "aws_route53_zone" "existing" {
  count = local.effective_create_hosted_zone ? 0 : 1

  name         = var.domain_name
  private_zone = false
}

# Local value to reference the correct hosted zone
locals {
  hosted_zone_id = local.effective_create_hosted_zone ? aws_route53_zone.main[0].zone_id : data.aws_route53_zone.existing[0].zone_id
}

# ACM Certificate (must be created in us-east-1 for CloudFront)
resource "aws_acm_certificate" "main" {
  provider = aws.us_east_1

  domain_name               = local.certificate_domains[0]
  subject_alternative_names = length(local.certificate_domains) > 1 ? slice(local.certificate_domains, 1, length(local.certificate_domains)) : []
  validation_method         = "DNS"

  # Certificate lifecycle management
  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.naming_prefix}-certificate"
      Domains = join(", ", local.certificate_domains)
    }
  )
}

# Route 53 records for ACM certificate validation
resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.hosted_zone_id

  depends_on = [aws_acm_certificate.main]
}

# ACM certificate validation
resource "aws_acm_certificate_validation" "main" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]

  timeouts {
    create = "10m"
  }

  depends_on = [aws_route53_record.certificate_validation]
}

# Route 53 A records for all domains (points to CloudFront distribution)
resource "aws_route53_record" "main" {
  for_each = var.cloudfront_distribution_domain_name != null ? toset(local.certificate_domains) : toset([])

  zone_id = local.hosted_zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = var.cloudfront_distribution_domain_name
    zone_id                = var.cloudfront_distribution_hosted_zone_id
    evaluate_target_health = false
  }

  depends_on = [aws_acm_certificate_validation.main]
}

# Route 53 AAAA records for IPv6 support (if enabled)
resource "aws_route53_record" "ipv6" {
  for_each = var.cloudfront_distribution_domain_name != null && local.effective_enable_ipv6 ? toset(local.certificate_domains) : toset([])

  zone_id = local.hosted_zone_id
  name    = each.value
  type    = "AAAA"

  alias {
    name                   = var.cloudfront_distribution_domain_name
    zone_id                = var.cloudfront_distribution_hosted_zone_id
    evaluate_target_health = false
  }

  depends_on = [aws_acm_certificate_validation.main]
}

# Route 53 health check for monitoring (optional, for production environments)
resource "aws_route53_health_check" "main" {
  count = local.effective_enable_health_check && var.cloudfront_distribution_domain_name != null ? 1 : 0

  fqdn                            = local.primary_domain
  port                            = 443
  type                            = "HTTPS"
  resource_path                   = var.health_check_path
  failure_threshold               = var.health_check_failure_threshold
  request_interval                = var.health_check_request_interval
  cloudwatch_alarm_region         = data.aws_region.current.name
  cloudwatch_alarm_name           = "${local.naming_prefix}-health-check-alarm"
  insufficient_data_health_status = "LastKnownStatus"

  tags = merge(
    local.common_tags,
    {
      Name   = "${local.naming_prefix}-health-check"
      Domain = local.primary_domain
    }
  )
}