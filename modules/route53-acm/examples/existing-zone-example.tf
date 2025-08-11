# Existing Route 53 Zone Example
# This example shows how to use an existing Route 53 hosted zone

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

# Route 53 and ACM setup using existing hosted zone
module "route53_acm" {
  source = "../"

  # Required variables
  project_name = "my-nextjs-app"
  environment  = "staging"
  domain_name  = "placeholder.mx"

  # Use existing hosted zone instead of creating new one
  create_hosted_zone = false

  # Provider configuration
  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  tags = {
    Example = "existing-zone-route53-acm"
    Purpose = "SSL certificate with existing DNS zone"
  }
}

# Example outputs
output "certificate_arn" {
  description = "ARN of the created ACM certificate"
  value       = module.route53_acm.certificate_arn
}

output "hosted_zone_id" {
  description = "ID of the existing Route 53 hosted zone"
  value       = module.route53_acm.hosted_zone_id
}

output "domain_name" {
  description = "The configured domain name"
  value       = module.route53_acm.full_domain_name
}

output "certificate_validation_records" {
  description = "DNS validation records (for manual verification if needed)"
  value       = module.route53_acm.certificate_validation_records
}