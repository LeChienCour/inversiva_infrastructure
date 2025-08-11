# Complete Route 53 and ACM Certificate Example
# This example shows a full-featured setup with CloudFront integration

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

# Example S3 website bucket (would typically come from s3-website module)
resource "aws_s3_bucket" "website" {
  bucket = "my-nextjs-app-prod-website-example"

  tags = {
    Environment = "prod"
    Purpose     = "Static website hosting"
  }
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Example CloudFront distribution (simplified)
resource "aws_cloudfront_distribution" "website" {
  origin {
    domain_name = aws_s3_bucket.website.bucket_domain_name
    origin_id   = "S3-${aws_s3_bucket.website.id}"

    s3_origin_config {
      origin_access_identity = ""
    }
  }

  enabled             = true
  default_root_object = "index.html"

  # Use the certificate from our module
  viewer_certificate {
    acm_certificate_arn      = module.route53_acm.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # Use the domain from our module
  aliases = [module.route53_acm.full_domain_name]

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.website.id}"
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
    Environment = "prod"
    Purpose     = "CDN for Next.js app"
  }

  depends_on = [module.route53_acm]
}

# Complete Route 53 and ACM setup with all features
module "route53_acm" {
  source = "../"

  # Required variables
  project_name = "my-nextjs-app"
  environment  = "prod"
  domain_name  = "placeholder.mx"
  subdomain    = "app" # Creates app.placeholder.mx

  # Route 53 configuration
  create_hosted_zone = true
  enable_ipv6        = true

  # CloudFront integration
  cloudfront_distribution_domain_name    = aws_cloudfront_distribution.website.domain_name
  cloudfront_distribution_hosted_zone_id = aws_cloudfront_distribution.website.hosted_zone_id

  # Health monitoring
  enable_health_check            = true
  health_check_path              = "/health"
  health_check_failure_threshold = 3
  health_check_request_interval  = 30

  # Provider configuration
  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  tags = {
    Example    = "complete-route53-acm"
    Purpose    = "Full-featured SSL and DNS setup"
    Owner      = "DevOps Team"
    CostCenter = "Engineering"
  }

  depends_on = [aws_cloudfront_distribution.website]
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

output "full_domain_name" {
  description = "The full domain name (app.placeholder.mx)"
  value       = module.route53_acm.full_domain_name
}

output "name_servers" {
  description = "Name servers for the domain (configure these with your domain registrar)"
  value       = module.route53_acm.hosted_zone_name_servers
}

output "cloudfront_distribution_url" {
  description = "CloudFront distribution URL"
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
}

output "custom_domain_url" {
  description = "Custom domain URL"
  value       = "https://${module.route53_acm.full_domain_name}"
}

output "health_check_id" {
  description = "Route 53 health check ID"
  value       = module.route53_acm.health_check_id
}