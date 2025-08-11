# CloudFront Distribution Module Outputs

output "distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.id
}

output "distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.arn
}

output "distribution_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "distribution_hosted_zone_id" {
  description = "CloudFront Route 53 zone ID"
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}

output "distribution_status" {
  description = "Current status of the distribution"
  value       = aws_cloudfront_distribution.main.status
}

output "distribution_etag" {
  description = "Current version of the distribution's information"
  value       = aws_cloudfront_distribution.main.etag
}

output "distribution_last_modified_time" {
  description = "Date and time the distribution was last modified"
  value       = aws_cloudfront_distribution.main.last_modified_time
}

# Security and Policy Outputs
output "response_headers_policy_id" {
  description = "ID of the response headers policy"
  value       = aws_cloudfront_response_headers_policy.security_headers.id
}

output "response_headers_policy_etag" {
  description = "ETag of the response headers policy"
  value       = aws_cloudfront_response_headers_policy.security_headers.etag
}

# Configuration Outputs
output "price_class" {
  description = "Price class of the distribution"
  value       = aws_cloudfront_distribution.main.price_class
}

output "enabled" {
  description = "Whether the distribution is enabled"
  value       = aws_cloudfront_distribution.main.enabled
}

output "ipv6_enabled" {
  description = "Whether IPv6 is enabled for the distribution"
  value       = aws_cloudfront_distribution.main.is_ipv6_enabled
}

output "default_root_object" {
  description = "Default root object of the distribution"
  value       = aws_cloudfront_distribution.main.default_root_object
}

# Domain and Certificate Outputs
output "aliases" {
  description = "List of aliases (custom domains) for the distribution"
  value       = aws_cloudfront_distribution.main.aliases
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate used by the distribution"
  value       = var.acm_certificate_arn
}

output "custom_domain_configured" {
  description = "Whether a custom domain is configured"
  value       = var.domain_name != null
}

# Origin Configuration Outputs
output "origin_domain_name" {
  description = "Domain name of the S3 origin"
  value       = var.s3_bucket_domain_name
}

output "origin_access_control_id" {
  description = "ID of the Origin Access Control"
  value       = var.origin_access_control_id
}

# Monitoring Outputs
output "monitoring_enabled" {
  description = "Whether CloudWatch monitoring is enabled"
  value       = var.enable_monitoring
}

output "error_rate_alarm_arn" {
  description = "ARN of the error rate CloudWatch alarm (if enabled)"
  value       = var.enable_monitoring ? aws_cloudwatch_metric_alarm.error_rate[0].arn : null
}

output "origin_latency_alarm_arn" {
  description = "ARN of the origin latency CloudWatch alarm (if enabled)"
  value       = var.enable_monitoring ? aws_cloudwatch_metric_alarm.origin_latency[0].arn : null
}

# Logging Outputs
output "logging_enabled" {
  description = "Whether access logging is enabled"
  value       = var.logging_bucket != null
}

output "logging_bucket" {
  description = "S3 bucket used for access logging"
  value       = var.logging_bucket
}

# Security Configuration Outputs
output "web_acl_id" {
  description = "AWS WAF web ACL ID associated with the distribution"
  value       = var.web_acl_id
}

output "minimum_tls_version" {
  description = "Minimum TLS version configured for the distribution"
  value       = var.minimum_tls_version
}

output "geo_restriction_type" {
  description = "Type of geographic restriction configured"
  value       = var.geo_restriction_type
}

output "geo_restriction_locations" {
  description = "List of countries for geographic restrictions"
  value       = var.geo_restriction_locations
}

# CORS Configuration Outputs
output "cors_configured" {
  description = "Whether CORS is configured"
  value       = length(var.cors_allow_origins) > 0
}

output "cors_allow_origins" {
  description = "List of allowed CORS origins"
  value       = var.cors_allow_origins
}

# Cache Behavior Information
output "cache_behaviors_configured" {
  description = "Information about configured cache behaviors"
  value = {
    default_behavior = "Next.js optimized with security headers"
    api_routes       = "No caching for /api/* paths"
    static_assets    = "Long-term caching for /_next/static/*"
    media_files      = "Optimized caching for images and media"
  }
}

# Environment and Project Information
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}