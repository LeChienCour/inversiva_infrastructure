# CloudFront Distribution Module

This Terraform module creates a CloudFront distribution optimized for Next.js applications with custom domain support, ACM certificate integration, security headers, and CORS policies.

## Features

- **Next.js Optimized**: Cache behaviors specifically configured for Next.js applications
- **Custom Domain Support**: Integration with ACM certificates for custom domains
- **Security Headers**: Comprehensive security headers including CSP, HSTS, and more
- **CORS Configuration**: Flexible CORS policy configuration for API integration
- **Cost Optimization**: Environment-specific price classes and caching strategies
- **Monitoring**: Optional CloudWatch alarms for error rates and latency
- **Geographic Restrictions**: Support for geo-blocking and geo-allowing
- **Access Logging**: Optional S3 access logging with customizable prefixes

## Usage

### Basic Usage

```hcl
module "cloudfront" {
  source = "./modules/cloudfront"

  project_name               = "my-nextjs-app"
  environment               = "prod"
  s3_bucket_domain_name     = "my-bucket.s3.amazonaws.com"
  origin_access_control_id  = "E1234567890123"
  
  # Custom domain configuration
  domain_name           = "example.com"
  acm_certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
  
  tags = {
    Project = "MyNextJSApp"
    Owner   = "DevOps Team"
  }
}
```

### Advanced Configuration

```hcl
module "cloudfront" {
  source = "./modules/cloudfront"

  project_name               = "my-nextjs-app"
  environment               = "prod"
  s3_bucket_domain_name     = "my-bucket.s3.amazonaws.com"
  origin_access_control_id  = "E1234567890123"
  
  # Custom domain and security
  domain_name           = "app.example.com"
  acm_certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
  minimum_tls_version   = "TLSv1.2_2021"
  
  # Security configuration
  content_security_policy = "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';"
  web_acl_id             = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/MyWebACL/12345678-1234-1234-1234-123456789012"
  
  # CORS configuration for API integration
  cors_allow_credentials = true
  cors_allow_origins     = ["https://app.example.com", "https://admin.example.com"]
  cors_allow_headers     = ["Accept", "Authorization", "Content-Type", "X-Requested-With"]
  
  # Geographic restrictions
  geo_restriction_type      = "whitelist"
  geo_restriction_locations = ["US", "CA", "GB"]
  
  # Monitoring and logging
  enable_monitoring         = true
  error_rate_threshold      = 3.0
  origin_latency_threshold  = 3000
  logging_bucket           = "my-cloudfront-logs-bucket"
  logging_include_cookies  = false
  
  # Custom error responses for SPA routing
  custom_error_responses = [
    {
      error_code            = 404
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 300
    },
    {
      error_code            = 403
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 300
    }
  ]
  
  # Custom headers
  custom_headers = [
    {
      header   = "X-Custom-Header"
      value    = "MyCustomValue"
      override = true
    }
  ]
  
  tags = {
    Project     = "MyNextJSApp"
    Environment = "prod"
    Owner       = "DevOps Team"
  }
}
```

## Cache Behaviors

This module configures several cache behaviors optimized for Next.js applications:

### Default Behavior
- **Path**: `/*` (all paths)
- **TTL**: 1 day default, 1 year maximum
- **Compression**: Enabled
- **Security Headers**: Applied via response headers policy

### API Routes
- **Path**: `/api/*`
- **TTL**: No caching (0 seconds)
- **Headers**: Forwards Authorization and CloudFront-Forwarded-Proto
- **Cookies**: Forwards all cookies

### Static Assets
- **Path**: `/_next/static/*`
- **TTL**: 1 year (immutable Next.js assets)
- **Compression**: Enabled
- **Query Strings**: Ignored

### Media Files
- **Path**: `*.{jpg,jpeg,png,gif,ico,svg,webp,avif}`
- **TTL**: 1 week default, 1 year maximum
- **Compression**: Enabled
- **Query Strings**: Ignored

## Security Features

### Security Headers
The module automatically configures the following security headers:

- **Strict-Transport-Security**: `max-age=31536000; includeSubDomains; preload`
- **X-Content-Type-Options**: `nosniff`
- **X-Frame-Options**: `DENY`
- **Referrer-Policy**: `strict-origin-when-cross-origin`
- **Content-Security-Policy**: Configurable via `content_security_policy` variable

### CORS Configuration
Flexible CORS configuration supporting:
- Custom allowed origins, methods, and headers
- Credential support for authenticated requests
- Configurable preflight cache duration
- Header exposure control

### TLS Configuration
- Minimum TLS version enforcement (default: TLSv1.2_2021)
- SNI-only SSL support for cost optimization
- Automatic HTTPS redirect

## Cost Optimization

### Environment-Based Pricing
- **Development**: PriceClass_100 (US, Canada, Europe) - Most cost-effective
- **Production**: PriceClass_200 (US, Canada, Europe, Asia, Middle East, Africa) - Balanced cost/performance
- **Override**: Use `price_class` variable to explicitly set pricing tier

### Intelligent Caching Strategy
- **Static Assets**: Environment-optimized TTLs (1 year prod, 1 day dev)
- **Default Content**: Shorter TTLs for cost control (1 hour prod, 30 min dev)
- **Media Files**: Balanced caching (1 day prod, 1 hour dev)
- **API Routes**: No caching to avoid unnecessary costs
- **Compression**: Enabled for all content types to reduce bandwidth costs

### Additional Cost Savings
- IPv6 disabled by default (enable only if needed)
- Monitoring disabled by default (enable only for production)
- SNI-only SSL certificates (no dedicated IP costs)
- Optimized cache behaviors to maximize hit ratios

## Monitoring and Alerting

When `enable_monitoring` is set to `true`, the module creates CloudWatch alarms for:

### Error Rate Monitoring
- Monitors 4xx error rate percentage
- Default threshold: 5%
- Evaluation period: 2 periods of 5 minutes

### Origin Latency Monitoring
- Monitors response time from S3 origin
- Default threshold: 5000ms
- Evaluation period: 2 periods of 5 minutes

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |
| random | >= 3.1 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |
| random | >= 3.1 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Name of the project, used for resource naming | `string` | n/a | yes |
| environment | Environment name (dev, staging, prod) | `string` | n/a | yes |
| s3_bucket_domain_name | Domain name of the S3 bucket to use as origin | `string` | n/a | yes |
| origin_access_control_id | ID of the CloudFront Origin Access Control for S3 bucket | `string` | n/a | yes |
| domain_name | Custom domain name for the CloudFront distribution | `string` | `null` | no |
| acm_certificate_arn | ARN of the ACM certificate for custom domain (must be in us-east-1) | `string` | `null` | no |
| minimum_tls_version | Minimum TLS version for HTTPS connections | `string` | `"TLSv1.2_2021"` | no |
| default_root_object | Default root object for the distribution | `string` | `"index.html"` | no |
| enable_ipv6 | Enable IPv6 support for the distribution (disable for cost savings if not needed) | `bool` | `false` | no |
| price_class | Price class for the distribution (PriceClass_100, PriceClass_200, PriceClass_All) | `string` | `null` | no |
| web_acl_id | AWS WAF web ACL ID to associate with the distribution | `string` | `null` | no |
| geo_restriction_type | Type of geographic restriction (none, whitelist, blacklist) | `string` | `"none"` | no |
| geo_restriction_locations | List of country codes for geographic restrictions | `list(string)` | `[]` | no |
| content_security_policy | Content Security Policy header value | `string` | `"default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:; frame-ancestors 'none';"` | no |
| cors_allow_credentials | Whether to allow credentials in CORS requests | `bool` | `false` | no |
| cors_allow_headers | List of headers allowed in CORS requests | `list(string)` | `["Accept", "Accept-Language", "Content-Language", "Content-Type", "Authorization"]` | no |
| cors_allow_methods | List of HTTP methods allowed in CORS requests | `list(string)` | `["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]` | no |
| cors_allow_origins | List of origins allowed in CORS requests | `list(string)` | `["*"]` | no |
| cors_expose_headers | List of headers exposed in CORS responses | `list(string)` | `[]` | no |
| cors_max_age_seconds | Maximum age in seconds for CORS preflight requests | `number` | `86400` | no |
| custom_error_responses | List of custom error response configurations | `list(object)` | See default SPA configuration | no |
| logging_bucket | S3 bucket name for CloudFront access logs | `string` | `null` | no |
| logging_include_cookies | Whether to include cookies in access logs | `bool` | `false` | no |
| enable_monitoring | Enable CloudWatch monitoring and alarms | `bool` | `false` | no |
| error_rate_threshold | Threshold for 4xx error rate alarm (percentage) | `number` | `5.0` | no |
| origin_latency_threshold | Threshold for origin latency alarm (milliseconds) | `number` | `5000` | no |
| alarm_actions | List of ARNs to notify when alarms trigger | `list(string)` | `[]` | no |
| custom_headers | List of custom headers to add to responses | `list(object)` | `[]` | no |
| tags | Additional tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| distribution_id | ID of the CloudFront distribution |
| distribution_arn | ARN of the CloudFront distribution |
| distribution_domain_name | Domain name of the CloudFront distribution |
| distribution_hosted_zone_id | CloudFront Route 53 zone ID |
| distribution_status | Current status of the distribution |
| response_headers_policy_id | ID of the response headers policy |
| price_class | Price class of the distribution |
| aliases | List of aliases (custom domains) for the distribution |
| monitoring_enabled | Whether CloudWatch monitoring is enabled |
| cors_configured | Whether CORS is configured |
| cache_behaviors_configured | Information about configured cache behaviors |

## Examples

### Development Environment

```hcl
module "cloudfront_dev" {
  source = "./modules/cloudfront"

  project_name               = "my-app"
  environment               = "dev"
  s3_bucket_domain_name     = module.s3_website_dev.bucket_domain_name
  origin_access_control_id  = module.s3_website_dev.origin_access_control_id
  
  # No custom domain for dev
  enable_monitoring = false
  
  tags = {
    Environment = "dev"
    Project     = "MyApp"
  }
}
```

### Production Environment with Full Configuration

```hcl
module "cloudfront_prod" {
  source = "./modules/cloudfront"

  project_name               = "my-app"
  environment               = "prod"
  s3_bucket_domain_name     = module.s3_website_prod.bucket_domain_name
  origin_access_control_id  = module.s3_website_prod.origin_access_control_id
  
  # Production domain and certificate
  domain_name           = "app.example.com"
  acm_certificate_arn   = module.acm_certificate.certificate_arn
  
  # Enhanced security
  web_acl_id = module.waf.web_acl_arn
  geo_restriction_type = "whitelist"
  geo_restriction_locations = ["US", "CA", "GB", "DE", "FR"]
  
  # Production monitoring
  enable_monitoring         = true
  error_rate_threshold      = 2.0
  origin_latency_threshold  = 2000
  alarm_actions            = [module.sns_alerts.topic_arn]
  
  # Access logging
  logging_bucket = module.s3_logs.bucket_id
  
  tags = {
    Environment = "prod"
    Project     = "MyApp"
    Critical    = "true"
  }
}
```

## Integration with Other Modules

This module is designed to work seamlessly with other modules in this infrastructure:

```hcl
# S3 Website Module provides the origin
module "s3_website" {
  source = "./modules/s3-website"
  # ... configuration
}

# CloudFront Distribution
module "cloudfront" {
  source = "./modules/cloudfront"
  
  s3_bucket_domain_name    = module.s3_website.bucket_domain_name
  origin_access_control_id = module.s3_website.origin_access_control_id
  
  # ... other configuration
}

# Route 53 and ACM for custom domain
module "route53" {
  source = "./modules/route53"
  
  domain_name                = var.domain_name
  cloudfront_domain_name     = module.cloudfront.distribution_domain_name
  cloudfront_hosted_zone_id  = module.cloudfront.distribution_hosted_zone_id
  
  # ... other configuration
}
```

## Cost Optimization Best Practices

### 1. Choose the Right Price Class
```hcl
# Most cost-effective (US, Canada, Europe)
price_class = "PriceClass_100"

# Balanced cost/performance (excludes most expensive regions)
price_class = "PriceClass_200"

# Global distribution (highest cost)
price_class = "PriceClass_All"  # Only use if you have global users
```

### 2. Optimize Cache TTLs
- **Static Assets**: Long TTLs (1 year) for immutable content
- **Dynamic Content**: Short TTLs (1 hour) to balance freshness and cost
- **API Routes**: No caching to avoid unnecessary origin requests

### 3. Disable Unnecessary Features
```hcl
# Disable IPv6 if not needed globally
enable_ipv6 = false

# Disable monitoring in development
enable_monitoring = var.environment == "prod"

# Disable logging unless required for compliance
logging_bucket = var.compliance_required ? var.log_bucket : null
```

### 4. Use Geographic Restrictions Wisely
```hcl
# Restrict to regions where you have users
geo_restriction_type = "whitelist"
geo_restriction_locations = ["US", "CA", "GB"]  # Only necessary regions
```

### 5. Optimize CORS Configuration
```hcl
# Restrict origins to reduce unnecessary traffic
cors_allow_origins = ["https://yourdomain.com"]  # Not "*"
cors_allow_methods = ["GET", "HEAD", "OPTIONS"]  # Only necessary methods
```

## Best Practices

1. **Certificate Management**: Always create ACM certificates in `us-east-1` region for CloudFront
2. **Security Headers**: Customize the Content Security Policy based on your application's needs
3. **CORS Configuration**: Restrict CORS origins to only necessary domains in production
4. **Monitoring**: Enable monitoring in production environments with appropriate thresholds
5. **Caching**: Leverage the optimized cache behaviors for better performance and cost savings
6. **Geographic Restrictions**: Use geo-restrictions only when necessary for compliance or security
7. **Cost Control**: Regularly review CloudWatch metrics to optimize cache hit ratios and reduce origin requests

## Troubleshooting

### Common Issues

1. **Certificate Validation**: Ensure ACM certificate is in `us-east-1` and validated
2. **Origin Access**: Verify that the S3 bucket policy allows CloudFront access
3. **Custom Domain**: Check that DNS records point to the CloudFront distribution
4. **Cache Issues**: Use cache invalidation for immediate content updates during development

### Debugging

- Check CloudFront distribution status in AWS Console
- Review CloudWatch metrics for error rates and latency
- Examine access logs if logging is enabled
- Verify security headers using browser developer tools

## License

This module is part of the terraform-nextjs-infrastructure project.