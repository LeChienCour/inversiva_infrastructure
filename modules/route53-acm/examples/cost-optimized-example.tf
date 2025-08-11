# Cost-Optimized Route 53 and ACM Certificate Example
# This example shows a minimal setup optimized for development environments

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider for us-east-1 (required for ACM certificates used with CloudFront)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# Cost-optimized Route 53 and ACM setup for development
module "route53_acm" {
  source = "../"

  # Required variables
  project_name = "my-nextjs-app"
  environment  = "dev"
  domain_name  = "placeholder.mx"
  subdomain    = "dev" # Creates dev.placeholder.mx

  # Cost optimization settings
  create_hosted_zone = false # Use existing zone to save $0.50/month
  enable_ipv6        = false # Disable IPv6 if not needed

  # Disable health checks to save $0.50/month per check
  enable_health_check = false

  # Provider configuration
  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  tags = {
    Example       = "cost-optimized-route53-acm"
    Purpose       = "Development SSL certificate"
    Environment   = "dev"
    CostOptimized = "true"
  }
}

# Example outputs
output "certificate_arn" {
  description = "ARN of the created ACM certificate"
  value       = module.route53_acm.certificate_arn
}

output "hosted_zone_id" {
  description = "ID of the Route 53 hosted zone"
  value       = module.route53_acm.hosted_zone_id
}

output "dev_domain_name" {
  description = "The development domain name (dev.placeholder.mx)"
  value       = module.route53_acm.full_domain_name
}

# Cost breakdown comment
/*
Cost breakdown for this configuration:
- Route 53 Hosted Zone: $0.00 (using existing zone)
- Route 53 DNS Queries: ~$0.40 per million queries
- ACM Certificate: $0.00 (free with AWS services)
- Health Checks: $0.00 (disabled)
- IPv6 Support: $0.00 (disabled)

Total estimated monthly cost: ~$0.00 + query costs
*/