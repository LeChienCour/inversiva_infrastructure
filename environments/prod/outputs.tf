# Production Environment - Output Values
# This file defines outputs that expose necessary values from all modules

# === ROUTE53 AND ACM OUTPUTS ===

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

output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = module.route53_acm.certificate_arn
}

output "certificate_validation_records" {
  description = "ACM certificate domain validation records"
  value       = module.route53_acm.certificate_validation_records
  sensitive   = true
}

# === COGNITO OUTPUTS ===

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.cognito.user_pool_id
}

output "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = module.cognito.user_pool_arn
}

output "cognito_user_pool_client_id" {
  description = "Cognito User Pool Client ID"
  value       = module.cognito.user_pool_client_id
  sensitive   = true
}

output "cognito_user_pool_client_secret" {
  description = "Cognito User Pool Client Secret"
  value       = module.cognito.user_pool_client_secret
  sensitive   = true
}

output "cognito_identity_pool_id" {
  description = "Cognito Identity Pool ID"
  value       = module.cognito.identity_pool_id
}

output "cognito_user_pool_domain" {
  description = "Cognito User Pool Domain"
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

# === S3 WEBSITE OUTPUTS ===

output "s3_website_bucket_name" {
  description = "S3 website bucket name"
  value       = module.s3_website.bucket_name
}

output "s3_website_bucket_id" {
  description = "ID of the S3 website bucket"
  value       = module.s3_website.bucket_id
}

output "s3_website_bucket_arn" {
  description = "S3 website bucket ARN"
  value       = module.s3_website.bucket_arn
}

output "s3_website_bucket_domain_name" {
  description = "S3 website bucket domain name"
  value       = module.s3_website.bucket_domain_name
}

output "s3_website_bucket_regional_domain_name" {
  description = "S3 website bucket regional domain name"
  value       = module.s3_website.bucket_regional_domain_name
}

output "s3_website_origin_access_control_id" {
  description = "CloudFront Origin Access Control ID for S3 website"
  value       = module.s3_website.origin_access_control_id
}

# === S3 CONTENT OUTPUTS ===

output "s3_content_bucket_name" {
  description = "S3 content bucket name"
  value       = module.s3_content.bucket_name
}

output "s3_content_bucket_id" {
  description = "ID of the S3 content bucket"
  value       = module.s3_content.bucket_id
}

output "s3_content_bucket_arn" {
  description = "S3 content bucket ARN"
  value       = module.s3_content.bucket_arn
}

output "s3_content_bucket_domain_name" {
  description = "S3 content bucket domain name"
  value       = module.s3_content.bucket_domain_name
}

output "s3_content_bucket_regional_domain_name" {
  description = "S3 content bucket regional domain name"
  value       = module.s3_content.bucket_regional_domain_name
}

# === CLOUDFRONT OUTPUTS ===

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.cloudfront.distribution_id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = module.cloudfront.distribution_arn
}

output "cloudfront_distribution_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.cloudfront.distribution_domain_name
}

output "cloudfront_distribution_hosted_zone_id" {
  description = "CloudFront distribution hosted zone ID"
  value       = module.cloudfront.distribution_hosted_zone_id
}

output "cloudfront_distribution_status" {
  description = "CloudFront distribution status"
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

output "monitoring_log_group_name" {
  description = "CloudWatch log group name created by monitoring module"
  value       = module.monitoring.log_group_name
}

output "monitoring_alarm_names" {
  description = "CloudWatch alarm names created by monitoring module"
  value       = module.monitoring.alarm_names
}

output "monitoring_sns_topic_arn" {
  description = "SNS topic ARN for monitoring alerts"
  value       = module.monitoring.sns_topic_arn
}

output "monitoring_dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = module.monitoring.dashboard_url
  sensitive   = false
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

output "domain_name" {
  description = "Primary domain name"
  value       = var.domain_name
}

output "root_domain" {
  description = "Root domain name"
  value       = var.root_domain
}

# === APPLICATION URLS ===

output "application_url" {
  description = "Main application URL"
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

# === DEPLOYMENT INFORMATION ===

output "deployment_timestamp" {
  description = "Deployment timestamp"
  value       = timestamp()
}

output "terraform_workspace" {
  description = "Terraform workspace"
  value       = terraform.workspace
}

# === SECURITY AND COMPLIANCE ===

output "data_classification" {
  description = "Data classification level"
  value       = var.data_classification
}

output "compliance_requirements" {
  description = "Compliance requirements"
  value       = var.compliance
}

output "backup_configuration" {
  description = "Backup configuration summary"
  value = {
    backup_required                   = var.backup_required
    cross_region_replication_enabled = var.backup_enable_cross_region_replication
    backup_region                     = var.backup_region
    retention_days                    = var.backup_retention_days
    point_in_time_recovery_enabled    = var.backup_enable_point_in_time_recovery
  }
}

# === COST OPTIMIZATION ===

output "cost_optimization_settings" {
  description = "Cost optimization settings summary"
  value = {
    s3_versioning_enabled         = var.s3_enable_versioning
    s3_lifecycle_policy_enabled   = var.s3_enable_lifecycle_policy
    s3_intelligent_tiering_enabled = var.s3_enable_intelligent_tiering
    cloudfront_price_class        = var.cloudfront_price_class
    auto_shutdown                 = var.auto_shutdown
    monitoring_level              = var.monitoring_level
  }
}