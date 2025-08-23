# Development Environment - Output Values
# This file exposes necessary values from all modules for external use

# === ROUTE53 AND ACM OUTPUTS ===

output "domain_name" {
  description = "The primary domain name"
  value       = var.domain_name
}

output "root_domain" {
  description = "The root domain name"
  value       = var.root_domain
}

output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = module.route53_acm.certificate_arn
}

output "certificate_validation_records" {
  description = "ACM certificate domain validation records"
  value       = module.route53_acm.certificate_validation_records
  sensitive   = true
}

output "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  value       = module.route53_acm.hosted_zone_id
}

output "hosted_zone_name_servers" {
  description = "Route53 hosted zone name servers"
  value       = module.route53_acm.hosted_zone_name_servers
}

output "primary_domain_record_fqdn" {
  description = "FQDN of the primary domain A record"
  value       = module.route53_acm.primary_domain_record_fqdn
}

output "all_domain_names" {
  description = "List of all domain names included in the certificate"
  value       = module.route53_acm.all_domain_names
}

# === COGNITO OUTPUTS ===

output "cognito_user_pool_id" {
  description = "ID of the Cognito user pool"
  value       = module.cognito.user_pool_id
}

output "cognito_user_pool_arn" {
  description = "ARN of the Cognito user pool"
  value       = module.cognito.user_pool_arn
}

output "cognito_user_pool_client_id" {
  description = "ID of the Cognito user pool client"
  value       = module.cognito.user_pool_client_id
}

output "cognito_user_pool_client_secret" {
  description = "Secret of the Cognito user pool client"
  value       = module.cognito.user_pool_client_secret
  sensitive   = true
}

output "cognito_user_pool_domain" {
  description = "Domain of the Cognito user pool"
  value       = module.cognito.user_pool_domain
}

output "cognito_user_pool_endpoint" {
  description = "Endpoint of the Cognito user pool"
  value       = module.cognito.user_pool_endpoint
}

output "cognito_config" {
  description = "Complete Cognito configuration for frontend integration"
  value       = module.cognito.cognito_config
  sensitive   = true
}

output "cognito_identity_pool_id" {
  description = "ID of the Cognito identity pool"
  value       = module.cognito.identity_pool_id
}

output "cognito_identity_pool_arn" {
  description = "ARN of the Cognito identity pool"
  value       = module.cognito.identity_pool_arn
}

output "cognito_authenticated_role_arn" {
  description = "ARN of the authenticated IAM role"
  value       = module.cognito.authenticated_role_arn
}

output "cognito_unauthenticated_role_arn" {
  description = "ARN of the unauthenticated IAM role"
  value       = module.cognito.unauthenticated_role_arn
}

# === S3 WEBSITE OUTPUTS ===

output "s3_website_bucket_name" {
  description = "Name of the S3 website bucket"
  value       = module.s3_website.bucket_name
}

output "s3_website_bucket_id" {
  description = "ID of the S3 website bucket"
  value       = module.s3_website.bucket_id
}

output "s3_website_bucket_arn" {
  description = "ARN of the S3 website bucket"
  value       = module.s3_website.bucket_arn
}

output "s3_website_bucket_domain_name" {
  description = "Domain name of the S3 website bucket"
  value       = module.s3_website.bucket_domain_name
}

output "s3_website_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 website bucket"
  value       = module.s3_website.bucket_regional_domain_name
}

# === S3 CONTENT OUTPUTS ===

output "s3_content_bucket_name" {
  description = "Name of the S3 content bucket"
  value       = module.s3_content.bucket_name
}

output "s3_content_bucket_id" {
  description = "ID of the S3 content bucket"
  value       = module.s3_content.bucket_id
}

output "s3_content_bucket_arn" {
  description = "ARN of the S3 content bucket"
  value       = module.s3_content.bucket_arn
}

output "s3_content_bucket_domain_name" {
  description = "Domain name of the S3 content bucket"
  value       = module.s3_content.bucket_domain_name
}

output "s3_content_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 content bucket"
  value       = module.s3_content.bucket_regional_domain_name
}

# === CLOUDFRONT OUTPUTS ===

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = module.cloudfront.distribution_id
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = module.cloudfront.distribution_arn
}

output "cloudfront_distribution_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = module.cloudfront.distribution_domain_name
}

output "cloudfront_distribution_hosted_zone_id" {
  description = "Hosted zone ID of the CloudFront distribution"
  value       = module.cloudfront.distribution_hosted_zone_id
}

output "cloudfront_origin_access_control_id" {
  description = "ID of the CloudFront Origin Access Control"
  value       = module.cloudfront.origin_access_control_id
}

output "cloudfront_distribution_status" {
  description = "Status of the CloudFront distribution"
  value       = module.cloudfront.distribution_status
}

output "cloudfront_distribution_etag" {
  description = "Current version of the distribution's information"
  value       = module.cloudfront.distribution_etag
}

output "cloudfront_price_class" {
  description = "Price class of the CloudFront distribution"
  value       = module.cloudfront.price_class
}

# === MONITORING OUTPUTS ===

output "monitoring_dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = module.monitoring.dashboard_url
  sensitive   = false
}

output "monitoring_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = module.monitoring.log_group_name
}

output "monitoring_alarm_names" {
  description = "Names of the CloudWatch alarms"
  value       = module.monitoring.alarm_names
}

output "monitoring_sns_topic_arn" {
  description = "SNS topic ARN for monitoring alerts"
  value       = module.monitoring.sns_topic_arn
}

# === ENVIRONMENT INFORMATION ===

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "common_tags" {
  description = "Common tags applied to all resources"
  value       = local.common_tags
}

# === APPLICATION URLS ===

output "application_url" {
  description = "Primary application URL"
  value       = "https://${var.domain_name}"
}

output "cloudfront_url" {
  description = "CloudFront distribution URL"
  value       = "https://${module.cloudfront.distribution_domain_name}"
}

output "cognito_hosted_ui_url" {
  description = "Cognito Hosted UI URL"
  value       = "https://${module.cognito.user_pool_domain}.auth.${var.aws_region}.amazoncognito.com"
}

output "cognito_login_url" {
  description = "Cognito hosted UI login URL"
  value       = "https://${module.cognito.user_pool_domain}/login?client_id=${module.cognito.user_pool_client_id}&response_type=code&scope=email+openid+profile&redirect_uri=${urlencode(var.cognito_callback_urls[0])}"
}

# === DEPLOYMENT INFORMATION ===

output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    environment                = var.environment
    domain_name                = var.domain_name
    cloudfront_distribution_id = module.cloudfront.distribution_id
    s3_website_bucket          = module.s3_website.bucket_name
    s3_content_bucket          = module.s3_content.bucket_name
    cognito_user_pool_id       = module.cognito.user_pool_id
    certificate_arn            = module.route53_acm.certificate_arn
    hosted_zone_id             = module.route53_acm.hosted_zone_id
  }
}

# === DEPLOYMENT INFORMATION ===

output "deployment_timestamp" {
  description = "Deployment timestamp"
  value       = timestamp()
}

output "terraform_workspace" {
  description = "Terraform workspace"
  value       = terraform.workspace
}

# === COST OPTIMIZATION ===

output "cost_optimization_settings" {
  description = "Cost optimization settings summary"
  value = {
    s3_versioning_enabled         = var.s3_enable_versioning
    s3_lifecycle_policy_enabled   = var.s3_enable_lifecycle_policy
    s3_intelligent_tiering_enabled = var.s3_enable_intelligent_tiering
    cloudfront_price_class        = var.cloudfront_price_class
    cloudfront_monitoring_enabled = var.cloudfront_enable_monitoring
    route53_health_check_enabled  = var.route53_enable_health_check
  }
}