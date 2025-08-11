# Simple Multiple Subdomains Example
# This example shows the most common multiple subdomain setup

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

# Simple multiple subdomains setup - most common use case
module "route53_acm" {
  source = "../"
  
  # Required variables
  project_name = "my-nextjs-app"
  environment  = "prod"
  domain_name  = "placeholder.mx"
  
  # Common subdomains for a web application
  subdomains = [
    "www",  # Main website
    "api",  # API endpoints
    "app"   # Web application
  ]
  
  # Include root domain (placeholder.mx) in certificate
  include_root_domain = true
  
  # Use www as primary domain
  primary_subdomain = "www"
  
  # Provider configuration
  providers = {
    aws.us_east_1 = aws.us_east_1
  }
  
  tags = {
    Example = "simple-multiple-subdomains"
    Purpose = "Common web app subdomain setup"
  }
}

# Example outputs
output "certificate_arn" {
  description = "Use this ARN in your CloudFront distribution"
  value       = module.route53_acm.certificate_arn
}

output "all_domains" {
  description = "All domains covered by the certificate"
  value       = module.route53_acm.all_domain_names
}

output "primary_domain" {
  description = "Primary domain for your application"
  value       = module.route53_acm.full_domain_name
}

output "setup_instructions" {
  description = "Next steps to complete the setup"
  value = {
    step_1 = "Configure your domain registrar to use these name servers: ${join(", ", module.route53_acm.hosted_zone_name_servers)}"
    step_2 = "Use certificate ARN in CloudFront: ${module.route53_acm.certificate_arn}"
    step_3 = "Add these aliases to CloudFront: ${join(", ", module.route53_acm.all_domain_names)}"
    step_4 = "Update Route 53 records to point to CloudFront distribution"
  }
}