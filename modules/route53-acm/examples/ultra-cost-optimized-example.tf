# Ultra Cost-Optimized Route 53 and ACM Certificate Example
# This example shows the absolute minimum cost configuration

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

# Ultra cost-optimized setup - ZERO monthly fixed costs
module "route53_acm" {
  source = "../"

  # Required variables
  project_name = "my-nextjs-app"
  environment  = "dev"
  domain_name  = "placeholder.mx"
  subdomain    = "dev"

  # Ultra cost optimization - all expensive features disabled
  create_hosted_zone  = false # Use existing zone - saves $0.50/month
  enable_health_check = false # No health checks - saves $0.50/month
  enable_ipv6         = false # No IPv6 if not needed

  # Enable automatic cost optimizations for dev environment
  cost_optimization_enabled = true

  # Provider configuration
  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  tags = {
    Example       = "ultra-cost-optimized"
    Purpose       = "Zero fixed cost SSL certificate"
    Environment   = "dev"
    CostOptimized = "ultra"
  }
}

# Example outputs
output "certificate_arn" {
  description = "ARN of the created ACM certificate"
  value       = module.route53_acm.certificate_arn
}

output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown"
  value       = module.route53_acm.estimated_monthly_cost
}

output "cost_optimization_applied" {
  description = "Cost optimization settings applied"
  value       = module.route53_acm.cost_optimization_applied
}

# Cost breakdown for ultra-optimized configuration
output "cost_breakdown" {
  description = "Detailed cost breakdown"
  value = {
    route53_hosted_zone = "$0.00 (using existing zone)"
    route53_dns_queries = "~$0.40 per million queries"
    acm_certificate     = "$0.00 (free with AWS services)"
    health_checks       = "$0.00 (disabled)"
    ipv6_support        = "$0.00 (disabled)"
    total_monthly_fixed = "$0.00"
    note                = "Only pay for DNS queries (~$0.40 per million)"
  }
}

/*
ULTRA COST OPTIMIZATION STRATEGY:

1. Use existing Route 53 hosted zone (saves $0.50/month)
2. Disable health checks (saves $0.50/month)  
3. Disable IPv6 if not needed (no cost but reduces complexity)
4. ACM certificate is always free with AWS services
5. Only cost is DNS queries (~$0.40 per million queries)

TOTAL MONTHLY COST: $0.00 fixed + query costs

This configuration is perfect for:
- Development environments
- Low-traffic applications
- Cost-sensitive projects
- Proof of concepts

For production, consider enabling health checks for monitoring.
*/