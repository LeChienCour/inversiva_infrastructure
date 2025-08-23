# Auto-generated terraform.tfvars from environment variables
# Generated on: Sat, Aug 23, 2025  5:18:03 PM
# Environment: dev

# Project Configuration
project_name = "terraform-nextjs-infrastructure"
environment  = "dev"
aws_region   = "us-east-1"

# Domain Configuration
domain_name = "dev.placeholder.mx"
root_domain = "placeholder.mx"

# Cognito Configuration
cognito_min_password_length    = 8
cognito_require_lowercase      = true
cognito_require_numbers        = true
cognito_require_symbols        = false
cognito_require_uppercase      = true
cognito_temp_password_validity = 7

# S3 Configuration
s3_enable_versioning           = false
s3_content_bucket_prefix       = "inversiva-dev-content"

# CloudFront Configuration
cloudfront_price_class = "PriceClass_100"

# Route53 Configuration
route53_create_hosted_zone = false

# CORS Configuration
cors_allow_origins = ["http://localhost:3000", "https://dev.placeholder.mx"]

# Common Tags
common_tags = {
  Project     = "terraform-nextjs-infrastructure"
  Environment = "dev"
  ManagedBy   = "terraform"
  CreatedBy   = "terraform"
}
