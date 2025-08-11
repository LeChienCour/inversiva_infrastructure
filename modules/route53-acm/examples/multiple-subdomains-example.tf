# Multiple Subdomains Route 53 and ACM Certificate Example
# This example shows how to configure multiple subdomains with a single certificate

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

# Multiple subdomains setup
module "route53_acm_multiple" {
  source = "../"

  # Required variables
  project_name = "my-nextjs-app"
  environment  = "prod"
  domain_name  = "placeholder.mx"

  # Multiple subdomains configuration
  subdomains = [
    "www",   # www.placeholder.mx
    "api",   # api.placeholder.mx
    "app",   # app.placeholder.mx
    "admin", # admin.placeholder.mx
    "blog"   # blog.placeholder.mx
  ]

  # Include root domain in certificate (placeholder.mx)
  include_root_domain = true

  # Set primary subdomain for health checks and main DNS record
  primary_subdomain = "www"

  # Route 53 configuration
  create_hosted_zone = true
  enable_ipv6        = true

  # Health monitoring on primary domain
  enable_health_check            = true
  health_check_path              = "/"
  health_check_failure_threshold = 3
  health_check_request_interval  = 30

  # Provider configuration
  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  tags = {
    Example    = "multiple-subdomains-route53-acm"
    Purpose    = "Multi-subdomain SSL certificate"
    Subdomains = "www,api,app,admin,blog"
  }
}

# Example CloudFront distributions for different subdomains
# You would typically have different CloudFront distributions for different purposes

# Main website (www.placeholder.mx)
resource "aws_cloudfront_distribution" "website" {
  # ... CloudFront configuration for main website

  # Use the certificate from our module
  viewer_certificate {
    acm_certificate_arn      = module.route53_acm_multiple.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # Multiple aliases supported by the certificate
  aliases = [
    "www.placeholder.mx",
    "placeholder.mx" # Root domain
  ]

  # ... rest of CloudFront configuration

  origin {
    domain_name = "example-website-bucket.s3.amazonaws.com"
    origin_id   = "S3-website"

    s3_origin_config {
      origin_access_identity = ""
    }
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-website"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "website-distribution"
  }
}

# API CloudFront distribution (api.placeholder.mx)
resource "aws_cloudfront_distribution" "api" {
  # ... CloudFront configuration for API

  viewer_certificate {
    acm_certificate_arn      = module.route53_acm_multiple.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  aliases = ["api.placeholder.mx"]

  # ... rest of configuration for API

  origin {
    domain_name = "api-backend.example.com"
    origin_id   = "API-backend"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled = true

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "API-backend"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type"]
      cookies {
        forward = "all"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "api-distribution"
  }
}

# Update Route 53 records to point to CloudFront distributions
module "route53_acm_with_cloudfront" {
  source = "../"

  # Same configuration as above
  project_name = "my-nextjs-app"
  environment  = "prod"
  domain_name  = "placeholder.mx"

  subdomains = [
    "www",
    "api",
    "app",
    "admin",
    "blog"
  ]

  include_root_domain = true
  primary_subdomain   = "www"

  # Point to main website CloudFront distribution
  # Note: In a real scenario, you might need separate modules for different distributions
  cloudfront_distribution_domain_name    = aws_cloudfront_distribution.website.domain_name
  cloudfront_distribution_hosted_zone_id = aws_cloudfront_distribution.website.hosted_zone_id

  create_hosted_zone  = false # Use the zone created by the first module
  enable_ipv6         = true
  enable_health_check = true

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  depends_on = [
    module.route53_acm_multiple,
    aws_cloudfront_distribution.website,
    aws_cloudfront_distribution.api
  ]
}

# Example outputs
output "certificate_arn" {
  description = "ARN of the multi-domain ACM certificate"
  value       = module.route53_acm_multiple.certificate_arn
}

output "all_domain_names" {
  description = "All domain names included in the certificate"
  value       = module.route53_acm_multiple.all_domain_names
}

output "primary_domain" {
  description = "Primary domain name (www.placeholder.mx)"
  value       = module.route53_acm_multiple.full_domain_name
}

output "subdomain_fqdns" {
  description = "All subdomain FQDNs"
  value       = module.route53_acm_multiple.subdomain_fqdns
}

output "hosted_zone_id" {
  description = "Route 53 hosted zone ID"
  value       = module.route53_acm_multiple.hosted_zone_id
}

output "name_servers" {
  description = "Name servers for the domain"
  value       = module.route53_acm_multiple.hosted_zone_name_servers
}

output "domain_urls" {
  description = "All domain URLs"
  value = {
    for domain in module.route53_acm_multiple.all_domain_names :
    domain => "https://${domain}"
  }
}

# Cost breakdown for multiple subdomains
output "cost_breakdown" {
  description = "Cost breakdown for multiple subdomains setup"
  value = {
    certificate_domains = length(module.route53_acm_multiple.all_domain_names)
    estimated_cost      = module.route53_acm_multiple.estimated_monthly_cost
    note                = "Single certificate covers all domains - no additional cost per domain"
  }
}