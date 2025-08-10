# CloudFront Distribution Module
# This module creates a CloudFront distribution optimized for Next.js applications
# with custom domain support, ACM certificate integration, and security headers

# Generate random suffix for unique resource naming
resource "random_id" "distribution_suffix" {
  byte_length = 4
}

# Local values for naming and configuration
locals {
  distribution_name = "${var.project_name}-${var.environment}-cloudfront-${random_id.distribution_suffix.hex}"

  # Environment-specific configurations for cost optimization
  # Use explicit price_class if provided, otherwise use environment-based defaults
  price_class = var.price_class != null ? var.price_class : (var.environment == "prod" ? "PriceClass_200" : "PriceClass_100")
  
  # Next.js optimized cache behaviors
  default_cache_behavior = {
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${var.s3_bucket_domain_name}"
    
    forwarded_values = {
      query_string = false
      cookies = {
        forward = "none"
      }
      headers = []
    }
    
    min_ttl     = 0
    default_ttl = local.cost_optimized_ttls.default_ttl
    max_ttl     = 86400   # 1 day (cost-optimized)
  }

  # Security headers for Next.js applications
  security_headers = {
    "Strict-Transport-Security" = "max-age=31536000; includeSubDomains; preload"
    "X-Content-Type-Options"    = "nosniff"
    "X-Frame-Options"           = "DENY"
    "X-XSS-Protection"          = "1; mode=block"
    "Referrer-Policy"           = "strict-origin-when-cross-origin"
    "Content-Security-Policy"   = var.content_security_policy
  }

  # Cost optimization settings
  cost_optimized_ttls = {
    # Shorter TTLs for better cost control vs performance balance
    default_ttl = var.environment == "prod" ? 3600 : 1800    # 1 hour prod, 30 min dev
    static_ttl  = var.environment == "prod" ? 31536000 : 86400 # 1 year prod, 1 day dev
    media_ttl   = var.environment == "prod" ? 86400 : 3600   # 1 day prod, 1 hour dev
  }

  common_tags = merge(var.tags, {
    Environment = var.environment
    Module      = "cloudfront"
    Purpose     = "cdn-distribution"
    CostCenter  = "infrastructure"
  })
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "main" {
  comment             = "CloudFront distribution for ${var.project_name} ${var.environment}"
  default_root_object = var.default_root_object
  enabled             = true
  is_ipv6_enabled     = var.enable_ipv6
  price_class         = local.price_class
  web_acl_id          = var.web_acl_id

  # S3 origin configuration
  origin {
    domain_name              = var.s3_bucket_domain_name
    origin_id                = "S3-${var.s3_bucket_domain_name}"
    origin_access_control_id = var.origin_access_control_id

    # Custom origin config for S3 website endpoint (if needed)
    dynamic "custom_origin_config" {
      for_each = var.use_s3_website_endpoint ? [1] : []
      content {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "http-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  # Custom domain configuration
  aliases = var.domain_name != null ? [var.domain_name] : []

  # Default cache behavior optimized for Next.js
  default_cache_behavior {
    target_origin_id       = local.default_cache_behavior.target_origin_id
    viewer_protocol_policy = local.default_cache_behavior.viewer_protocol_policy
    compress               = local.default_cache_behavior.compress
    
    allowed_methods = local.default_cache_behavior.allowed_methods
    cached_methods  = local.default_cache_behavior.cached_methods

    forwarded_values {
      query_string = local.default_cache_behavior.forwarded_values.query_string
      
      cookies {
        forward = local.default_cache_behavior.forwarded_values.cookies.forward
      }
      
      headers = local.default_cache_behavior.forwarded_values.headers
    }

    min_ttl     = local.default_cache_behavior.min_ttl
    default_ttl = local.default_cache_behavior.default_ttl
    max_ttl     = local.default_cache_behavior.max_ttl

    # Response headers policy for security
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id
  }

  # Next.js API routes cache behavior (no caching)
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "S3-${var.s3_bucket_domain_name}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "CloudFront-Forwarded-Proto"]
      
      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  # Static assets cache behavior (long caching)
  ordered_cache_behavior {
    path_pattern           = "/_next/static/*"
    target_origin_id       = "S3-${var.s3_bucket_domain_name}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      
      cookies {
        forward = "none"
      }
    }

    min_ttl     = local.cost_optimized_ttls.static_ttl
    default_ttl = local.cost_optimized_ttls.static_ttl
    max_ttl     = local.cost_optimized_ttls.static_ttl
  }

  # Images and media cache behavior
  ordered_cache_behavior {
    path_pattern           = "*.{jpg,jpeg,png,gif,ico,svg,webp,avif}"
    target_origin_id       = "S3-${var.s3_bucket_domain_name}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 3600     # 1 hour minimum
    default_ttl = local.cost_optimized_ttls.media_ttl
    max_ttl     = 604800   # 1 week maximum
  }

  # Geographic restrictions
  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  # SSL certificate configuration
  viewer_certificate {
    # Use ACM certificate for custom domain
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = var.acm_certificate_arn != null ? "sni-only" : null
    minimum_protocol_version = var.acm_certificate_arn != null ? var.minimum_tls_version : null
    
    # Use CloudFront default certificate when no ACM certificate is provided
    cloudfront_default_certificate = var.acm_certificate_arn == null ? true : null
  }

  # Custom error responses for Next.js SPA routing
  dynamic "custom_error_response" {
    for_each = var.custom_error_responses
    content {
      error_code            = custom_error_response.value.error_code
      response_code         = custom_error_response.value.response_code
      response_page_path    = custom_error_response.value.response_page_path
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
    }
  }

  # Logging configuration
  dynamic "logging_config" {
    for_each = var.logging_bucket != null ? [1] : []
    content {
      bucket          = var.logging_bucket
      prefix          = "cloudfront-logs/${local.distribution_name}/"
      include_cookies = var.logging_include_cookies
    }
  }

  tags = local.common_tags

  # Ensure distribution is created after origin access control
  depends_on = [aws_cloudfront_response_headers_policy.security_headers]
}

# Response headers policy for security headers
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name    = "${local.distribution_name}-security-headers"
  comment = "Security headers policy for ${var.project_name} ${var.environment}"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
  }

  # CORS configuration for Next.js applications
  cors_config {
    access_control_allow_credentials = var.cors_allow_credentials
    
    access_control_allow_headers {
      items = var.cors_allow_headers
    }
    
    access_control_allow_methods {
      items = var.cors_allow_methods
    }
    
    access_control_allow_origins {
      items = var.cors_allow_origins
    }
    
    access_control_expose_headers {
      items = var.cors_expose_headers
    }
    
    access_control_max_age_sec = var.cors_max_age_seconds
    origin_override            = true
  }

  # Custom headers
  dynamic "custom_headers_config" {
    for_each = length(var.custom_headers) > 0 ? [1] : []
    content {
      dynamic "items" {
        for_each = var.custom_headers
        content {
          header   = items.value.header
          value    = items.value.value
          override = items.value.override
        }
      }
    }
  }
}

# CloudFront monitoring alarm for error rate (optional)
resource "aws_cloudwatch_metric_alarm" "error_rate" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${local.distribution_name}-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = var.error_rate_threshold
  alarm_description   = "This metric monitors CloudFront 4xx error rate"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DistributionId = aws_cloudfront_distribution.main.id
  }

  tags = local.common_tags
}

# CloudFront monitoring alarm for origin latency (optional)
resource "aws_cloudwatch_metric_alarm" "origin_latency" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${local.distribution_name}-origin-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "OriginLatency"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = var.origin_latency_threshold
  alarm_description   = "This metric monitors CloudFront origin latency"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DistributionId = aws_cloudfront_distribution.main.id
  }

  tags = local.common_tags
}