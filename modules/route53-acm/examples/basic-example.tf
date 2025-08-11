# Basic Route 53 and ACM Certificate Example
# This example shows the minimal configuration needed for a custom domain

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

# Basic Route 53 and ACM setup
module "route53_acm" {
  source = "../"

  # Required variables
  project_name = "my-nextjs-app"
  environment  = "prod"
  domain_name  = "placeholder.mx"

  # Provider configuration
  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  tags = {
    Example = "basic-route53-acm"
    Purpose = "SSL certificate and DNS management"
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

output "domain_name" {
  description = "The configured domain name"
  value       = module.route53_acm.full_domain_name
}

output "name_servers" {
  description = "Name servers for the domain (configure these with your domain registrar)"
  value       = module.route53_acm.hosted_zone_name_servers
}