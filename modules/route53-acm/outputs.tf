# Route 53 and ACM Certificate Module Outputs

# Route 53 Outputs
output "hosted_zone_id" {
  description = "ID of the Route 53 hosted zone"
  value       = local.hosted_zone_id
}

output "hosted_zone_name_servers" {
  description = "Name servers for the hosted zone (only available if created by this module)"
  value       = local.effective_create_hosted_zone ? aws_route53_zone.main[0].name_servers : null
}

output "domain_name" {
  description = "The domain name configured for this module"
  value       = var.domain_name
}

output "full_domain_name" {
  description = "The primary full domain name (including subdomain if specified)"
  value       = local.primary_domain
}

output "all_domain_names" {
  description = "List of all domain names included in the certificate"
  value       = local.certificate_domains
}

output "subdomain_fqdns" {
  description = "List of all subdomain FQDNs (excluding root domain)"
  value       = local.subdomain_fqdns
}

# ACM Certificate Outputs
output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "certificate_domain_name" {
  description = "Domain name of the ACM certificate"
  value       = aws_acm_certificate.main.domain_name
}

output "certificate_subject_alternative_names" {
  description = "Subject alternative names of the ACM certificate"
  value       = aws_acm_certificate.main.subject_alternative_names
}

output "certificate_status" {
  description = "Status of the ACM certificate"
  value       = aws_acm_certificate.main.status
}

# DNS Validation Outputs
output "certificate_validation_records" {
  description = "DNS validation records for the certificate"
  value = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }
  sensitive = false
}

# Route 53 Record Outputs
output "domain_record_names" {
  description = "Map of domain names to their A record names"
  value = var.cloudfront_distribution_domain_name != null ? {
    for domain, record in aws_route53_record.main : domain => record.name
  } : {}
}

output "domain_record_fqdns" {
  description = "Map of domain names to their A record FQDNs"
  value = var.cloudfront_distribution_domain_name != null ? {
    for domain, record in aws_route53_record.main : domain => record.fqdn
  } : {}
}

output "primary_domain_record_name" {
  description = "Name of the primary domain A record"
  value = var.cloudfront_distribution_domain_name != null ? (
    contains(keys(aws_route53_record.main), local.primary_domain) ?
    aws_route53_record.main[local.primary_domain].name : null
  ) : null
}

output "primary_domain_record_fqdn" {
  description = "FQDN of the primary domain A record"
  value = var.cloudfront_distribution_domain_name != null ? (
    contains(keys(aws_route53_record.main), local.primary_domain) ?
    aws_route53_record.main[local.primary_domain].fqdn : null
  ) : null
}

# Health Check Outputs
output "health_check_id" {
  description = "ID of the Route 53 health check (if enabled)"
  value       = local.effective_enable_health_check && var.cloudfront_distribution_domain_name != null ? aws_route53_health_check.main[0].id : null
}

output "health_check_fqdn" {
  description = "FQDN being monitored by the health check"
  value       = local.effective_enable_health_check && var.cloudfront_distribution_domain_name != null ? aws_route53_health_check.main[0].fqdn : null
}

# Module Information
output "module_tags" {
  description = "Tags applied to resources created by this module"
  value       = local.common_tags
}

# Cost Optimization Outputs
output "estimated_monthly_cost" {
  description = "Estimated monthly cost in USD for this module's resources"
  value = {
    hosted_zone  = local.effective_create_hosted_zone ? 0.50 : 0.00
    health_check = local.effective_enable_health_check ? 0.50 : 0.00
    certificate  = 0.00 # ACM certificates are free with AWS services
    dns_queries  = "~$0.40 per million queries"
    total_fixed  = (local.effective_create_hosted_zone ? 0.50 : 0.00) + (local.effective_enable_health_check ? 0.50 : 0.00)
  }
}

output "cost_optimization_applied" {
  description = "Cost optimization settings that were applied"
  value = {
    environment                   = var.environment
    cost_optimization_enabled     = var.cost_optimization_enabled
    is_dev_environment            = local.is_dev_environment
    effective_create_hosted_zone  = local.effective_create_hosted_zone
    effective_enable_health_check = local.effective_enable_health_check
    effective_enable_ipv6         = local.effective_enable_ipv6
  }
}