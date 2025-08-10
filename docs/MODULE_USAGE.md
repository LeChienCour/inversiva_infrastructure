# Module Usage Guide

This document provides comprehensive examples and configuration options for all custom Terraform modules in the Next.js infrastructure project.

## Module Overview

The infrastructure consists of five custom modules, each designed for specific functionality:

| Module | Purpose | Dependencies |
|--------|---------|--------------|
| **cognito** | User authentication and authorization | None |
| **s3-website** | Static website hosting | None |
| **s3-content** | Private content storage with presigned URLs | None |
| **route53-acm** | DNS management and SSL certificates | None |
| **cloudfront** | CDN distribution and caching | s3-website, route53-acm |

## 1. Cognito Module

### Purpose
Provides AWS Cognito User Pool and Identity Pool for user authentication, authorization, and AWS resource access.

### Basic Usage

```hcl
module "cognito" {
  source = "../../../modules/cognito"
  
  # Required variables
  environment   = "dev"
  project_name  = "nextjs-app"
  domain_name   = "dev.placeholder.mx"
  
  # Optional variables with defaults
  user_pool_name = "nextjs-app-dev-users"
  
  tags = {
    Environment = "dev"
    Project     = "nextjs-infrastructure"
  }
}
```

### Advanced Configuration

```hcl
module "cognito" {
  source = "../../../modules/cognito"
  
  environment  = "prod"
  project_name = "nextjs-app"
  domain_name  = "placeholder.mx"
  
  # Custom password policy
  password_policy = {
    minimum_length    = 12
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }
  
  # MFA configuration
  mfa_configuration = "ON"  # OFF, ON, OPTIONAL
  
  # Advanced security features
  advanced_security_mode = "ENFORCED"  # OFF, AUDIT, ENFORCED
  
  # OAuth configuration
  oauth_flows = ["code"]
  oauth_scopes = ["email", "openid", "profile"]
  callback_urls = [
    "https://placeholder.mx/auth/callback",
    "http://localhost:3000/auth/callback"
  ]
  logout_urls = [
    "https://placeholder.mx/auth/logout",
    "http://localhost:3000/auth/logout"
  ]
  
  # Custom attributes
  custom_attributes = [
    {
      name                = "department"
      attribute_data_type = "String"
      required            = false
      mutable             = true
    }
  ]
  
  # Lambda triggers
  lambda_triggers = {
    pre_sign_up    = aws_lambda_function.pre_signup.arn
    post_confirmation = aws_lambda_function.post_confirmation.arn
  }
  
  tags = {
    Environment = "prod"
    Project     = "nextjs-infrastructure"
    Security    = "high"
  }
}
```

### Environment-Specific Examples

#### Development Environment
```hcl
module "cognito_dev" {
  source = "../../../modules/cognito"
  
  environment  = "dev"
  project_name = "nextjs-app"
  domain_name  = "dev.placeholder.mx"
  
  # Relaxed settings for development
  password_policy = {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = false
  }
  
  mfa_configuration      = "OPTIONAL"
  advanced_security_mode = "OFF"  # Save costs in dev
  
  # Development callback URLs
  callback_urls = [
    "http://localhost:3000/auth/callback",
    "https://dev.placeholder.mx/auth/callback"
  ]
  
  tags = {
    Environment = "dev"
    CostCenter  = "development"
  }
}
```

#### Production Environment
```hcl
module "cognito_prod" {
  source = "../../../modules/cognito"
  
  environment  = "prod"
  project_name = "nextjs-app"
  domain_name  = "placeholder.mx"
  
  # Strong security for production
  password_policy = {
    minimum_length    = 12
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }
  
  mfa_configuration      = "ON"
  advanced_security_mode = "ENFORCED"
  
  # Production URLs only
  callback_urls = ["https://placeholder.mx/auth/callback"]
  logout_urls   = ["https://placeholder.mx/auth/logout"]
  
  # Account recovery settings
  account_recovery_setting = {
    recovery_mechanisms = [
      {
        name     = "verified_email"
        priority = 1
      },
      {
        name     = "verified_phone_number"
        priority = 2
      }
    ]
  }
  
  tags = {
    Environment = "prod"
    Compliance  = "required"
    Backup      = "daily"
  }
}
```

### Integration with Next.js

```javascript
// Example Next.js integration
import { CognitoUserPool, CognitoUser, AuthenticationDetails } from 'amazon-cognito-identity-js';

const userPool = new CognitoUserPool({
  UserPoolId: 'us-east-1_XXXXXXXXX',  // From module output
  ClientId: 'XXXXXXXXXXXXXXXXXXXXXXXXXX'    // From module output
});

// Sign up
const signUp = (username, password, email) => {
  return new Promise((resolve, reject) => {
    userPool.signUp(username, password, [
      {
        Name: 'email',
        Value: email
      }
    ], null, (err, result) => {
      if (err) reject(err);
      else resolve(result);
    });
  });
};

// Sign in
const signIn = (username, password) => {
  const user = new CognitoUser({
    Username: username,
    Pool: userPool
  });
  
  const authDetails = new AuthenticationDetails({
    Username: username,
    Password: password
  });
  
  return new Promise((resolve, reject) => {
    user.authenticateUser(authDetails, {
      onSuccess: resolve,
      onFailure: reject
    });
  });
};
```

## 2. S3 Website Module

### Purpose
Provides S3 bucket configured for static website hosting with CloudFront integration.

### Basic Usage

```hcl
module "s3_website" {
  source = "../../../modules/s3-website"
  
  # Required variables
  environment  = "dev"
  project_name = "nextjs-app"
  domain_name  = "dev.placeholder.mx"
  
  tags = {
    Environment = "dev"
    Project     = "nextjs-infrastructure"
  }
}
```

### Advanced Configuration

```hcl
module "s3_website" {
  source = "../../../modules/s3-website"
  
  environment  = "prod"
  project_name = "nextjs-app"
  domain_name  = "placeholder.mx"
  
  # Custom bucket configuration
  bucket_prefix = "custom-website"
  
  # Versioning configuration
  enable_versioning = true
  noncurrent_version_expiration_days = 90
  
  # Lifecycle policies
  lifecycle_rules = [
    {
      id     = "optimize_storage"
      status = "Enabled"
      
      transition = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        }
      ]
      
      expiration = {
        days = 365
      }
    }
  ]
  
  # CORS configuration for API calls
  cors_rules = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "HEAD"]
      allowed_origins = ["https://placeholder.mx"]
      expose_headers  = ["ETag"]
      max_age_seconds = 3000
    }
  ]
  
  # Website configuration
  index_document = "index.html"
  error_document = "error.html"
  
  # Notification configuration
  notification_configuration = {
    lambda_configurations = [
      {
        lambda_function_arn = aws_lambda_function.process_upload.arn
        events             = ["s3:ObjectCreated:*"]
        filter_prefix      = "uploads/"
        filter_suffix      = ".jpg"
      }
    ]
  }
  
  tags = {
    Environment = "prod"
    Project     = "nextjs-infrastructure"
    Backup      = "enabled"
  }
}
```

### Environment-Specific Examples

#### Development Environment
```hcl
module "s3_website_dev" {
  source = "../../../modules/s3-website"
  
  environment  = "dev"
  project_name = "nextjs-app"
  domain_name  = "dev.placeholder.mx"
  
  # Cost optimization for dev
  enable_versioning = false
  
  lifecycle_rules = [
    {
      id     = "dev_cleanup"
      status = "Enabled"
      
      # Aggressive cleanup for dev
      transition = [
        {
          days          = 7
          storage_class = "STANDARD_IA"
        }
      ]
      
      expiration = {
        days = 30  # Short retention for dev
      }
    }
  ]
  
  # Simple CORS for development
  cors_rules = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "HEAD", "PUT", "POST", "DELETE"]
      allowed_origins = ["*"]  # Permissive for dev
      max_age_seconds = 300
    }
  ]
  
  tags = {
    Environment = "dev"
    AutoCleanup = "enabled"
  }
}
```

### Next.js Build Integration

```bash
#!/bin/bash
# deploy-nextjs.sh

# Build Next.js application
npm run build

# Sync build output to S3
aws s3 sync out/ s3://your-website-bucket/ \
  --delete \
  --cache-control "public, max-age=31536000" \
  --exclude "*.html" \
  --exclude "service-worker.js"

# Upload HTML files with shorter cache
aws s3 sync out/ s3://your-website-bucket/ \
  --delete \
  --cache-control "public, max-age=0, must-revalidate" \
  --include "*.html" \
  --include "service-worker.js"

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id YOUR_DISTRIBUTION_ID \
  --paths "/*"
```

## 3. S3 Content Module

### Purpose
Provides private S3 bucket for secure content storage with presigned URL access.

### Basic Usage

```hcl
module "s3_content" {
  source = "../../../modules/s3-content"
  
  # Required variables
  environment  = "dev"
  project_name = "nextjs-app"
  
  tags = {
    Environment = "dev"
    Project     = "nextjs-infrastructure"
  }
}
```

### Advanced Configuration

```hcl
module "s3_content" {
  source = "../../../modules/s3-content"
  
  environment  = "prod"
  project_name = "nextjs-app"
  
  # Custom bucket configuration
  bucket_prefix = "secure-content"
  
  # Encryption configuration
  kms_key_id = aws_kms_key.content_encryption.arn
  
  # Versioning and lifecycle
  enable_versioning = true
  noncurrent_version_expiration_days = 30
  
  # Lifecycle policies for cost optimization
  lifecycle_rules = [
    {
      id     = "content_lifecycle"
      status = "Enabled"
      
      transition = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        },
        {
          days          = 365
          storage_class = "DEEP_ARCHIVE"
        }
      ]
      
      # Keep content for compliance
      expiration = {
        days = 2555  # 7 years
      }
    }
  ]
  
  # Presigned URL configuration
  presigned_url_expiration = 900  # 15 minutes
  
  # Access logging
  access_logging = {
    target_bucket = aws_s3_bucket.access_logs.id
    target_prefix = "content-access-logs/"
  }
  
  # Notification for security monitoring
  notification_configuration = {
    lambda_configurations = [
      {
        lambda_function_arn = aws_lambda_function.security_monitor.arn
        events             = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
      }
    ]
  }
  
  tags = {
    Environment = "prod"
    Security    = "high"
    Compliance  = "required"
  }
}
```

### Presigned URL Generation Examples

```javascript
// Node.js example for generating presigned URLs
const AWS = require('aws-sdk');
const s3 = new AWS.S3();

// Generate presigned URL for upload
const generateUploadUrl = (key, contentType) => {
  const params = {
    Bucket: 'your-content-bucket',
    Key: key,
    Expires: 900, // 15 minutes
    ContentType: contentType,
    Conditions: [
      ['content-length-range', 0, 10485760], // Max 10MB
      ['starts-with', '$Content-Type', contentType]
    ]
  };
  
  return s3.getSignedUrl('putObject', params);
};

// Generate presigned URL for download
const generateDownloadUrl = (key) => {
  const params = {
    Bucket: 'your-content-bucket',
    Key: key,
    Expires: 900, // 15 minutes
    ResponseContentDisposition: 'attachment'
  };
  
  return s3.getSignedUrl('getObject', params);
};

// Usage in Next.js API route
export default async function handler(req, res) {
  const { key, action, contentType } = req.body;
  
  // Verify user authentication
  const user = await verifyToken(req.headers.authorization);
  if (!user) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  try {
    let url;
    if (action === 'upload') {
      url = generateUploadUrl(key, contentType);
    } else if (action === 'download') {
      url = generateDownloadUrl(key);
    }
    
    res.json({ url });
  } catch (error) {
    res.status(500).json({ error: 'Failed to generate URL' });
  }
}
```

## 4. Route53 ACM Module

### Purpose
Manages DNS records and SSL certificates for custom domain configuration.

### Basic Usage

```hcl
module "route53_acm" {
  source = "../../../modules/route53-acm"
  
  # Required variables
  domain_name = "placeholder.mx"
  
  tags = {
    Environment = "shared"
    Project     = "nextjs-infrastructure"
  }
}
```

### Advanced Configuration

```hcl
module "route53_acm" {
  source = "../../../modules/route53-acm"
  
  domain_name = "placeholder.mx"
  
  # Subject Alternative Names
  subject_alternative_names = [
    "*.placeholder.mx",
    "api.placeholder.mx",
    "admin.placeholder.mx"
  ]
  
  # Custom validation method
  validation_method = "DNS"  # DNS or EMAIL
  
  # Certificate transparency logging
  certificate_transparency_logging_preference = "ENABLED"
  
  # Custom DNS records
  additional_records = [
    {
      name    = "api"
      type    = "CNAME"
      ttl     = 300
      records = ["api-gateway.us-east-1.amazonaws.com"]
    },
    {
      name    = "mail"
      type    = "MX"
      ttl     = 300
      records = ["10 mail.placeholder.mx"]
    },
    {
      name    = ""
      type    = "TXT"
      ttl     = 300
      records = ["v=spf1 include:_spf.google.com ~all"]
    }
  ]
  
  # Health checks
  health_checks = [
    {
      fqdn                            = "placeholder.mx"
      port                           = 443
      type                           = "HTTPS"
      resource_path                  = "/health"
      failure_threshold              = 3
      request_interval               = 30
      cloudwatch_alarm_region        = "us-east-1"
      cloudwatch_alarm_name          = "website-health"
      insufficient_data_health_status = "Failure"
    }
  ]
  
  tags = {
    Environment = "shared"
    Project     = "nextjs-infrastructure"
    Monitoring  = "enabled"
  }
}
```

### Multi-Environment Setup

```hcl
# Shared domain and certificate
module "route53_acm_shared" {
  source = "../../../modules/route53-acm"
  
  domain_name = "placeholder.mx"
  
  subject_alternative_names = [
    "*.placeholder.mx"  # Covers dev.placeholder.mx, prod.placeholder.mx, etc.
  ]
  
  # Environment-specific records
  additional_records = [
    # Development
    {
      name    = "dev"
      type    = "A"
      alias = {
        name                   = module.cloudfront_dev.domain_name
        zone_id                = module.cloudfront_dev.hosted_zone_id
        evaluate_target_health = false
      }
    },
    # Production
    {
      name    = ""  # Root domain
      type    = "A"
      alias = {
        name                   = module.cloudfront_prod.domain_name
        zone_id                = module.cloudfront_prod.hosted_zone_id
        evaluate_target_health = true
      }
    },
    # API endpoints
    {
      name    = "api"
      type    = "CNAME"
      ttl     = 300
      records = [aws_api_gateway_domain_name.api.cloudfront_domain_name]
    }
  ]
  
  tags = {
    Environment = "shared"
    Project     = "nextjs-infrastructure"
  }
}
```

## 5. CloudFront Module

### Purpose
Provides CDN distribution with caching optimized for Next.js applications.

### Basic Usage

```hcl
module "cloudfront" {
  source = "../../../modules/cloudfront"
  
  # Required variables
  environment = "dev"
  domain_name = "dev.placeholder.mx"
  
  # S3 origin configuration
  s3_bucket_id                = module.s3_website.bucket_id
  s3_bucket_regional_domain_name = module.s3_website.bucket_regional_domain_name
  
  # Certificate
  acm_certificate_arn = module.route53_acm.certificate_arn
  
  tags = {
    Environment = "dev"
    Project     = "nextjs-infrastructure"
  }
}
```

### Advanced Configuration

```hcl
module "cloudfront" {
  source = "../../../modules/cloudfront"
  
  environment = "prod"
  domain_name = "placeholder.mx"
  
  # S3 origin
  s3_bucket_id                = module.s3_website.bucket_id
  s3_bucket_regional_domain_name = module.s3_website.bucket_regional_domain_name
  
  # Certificate
  acm_certificate_arn = module.route53_acm.certificate_arn
  
  # Distribution settings
  price_class = "PriceClass_All"  # Global distribution for production
  
  # Custom cache behaviors for Next.js
  cache_behaviors = [
    {
      path_pattern     = "/api/*"
      target_origin_id = "S3-Website"
      
      # API responses - short cache
      default_ttl = 0
      max_ttl     = 300
      min_ttl     = 0
      
      # Forward all headers for API
      headers = ["*"]
      
      # Forward query strings
      query_string = true
      
      # Compress responses
      compress = true
      
      viewer_protocol_policy = "redirect-to-https"
    },
    {
      path_pattern     = "/_next/static/*"
      target_origin_id = "S3-Website"
      
      # Static assets - long cache
      default_ttl = 31536000  # 1 year
      max_ttl     = 31536000
      min_ttl     = 31536000
      
      # No headers needed for static assets
      headers = []
      
      # No query strings
      query_string = false
      
      compress = true
      viewer_protocol_policy = "redirect-to-https"
    },
    {
      path_pattern     = "/images/*"
      target_origin_id = "S3-Website"
      
      # Images - medium cache
      default_ttl = 86400   # 1 day
      max_ttl     = 604800  # 1 week
      min_ttl     = 0
      
      headers = []
      query_string = false
      compress = true
      viewer_protocol_policy = "redirect-to-https"
    }
  ]
  
  # Security headers
  response_headers_policy = {
    cors = {
      access_control_allow_credentials = false
      access_control_allow_headers = ["*"]
      access_control_allow_methods = ["GET", "HEAD", "OPTIONS"]
      access_control_allow_origins = ["https://placeholder.mx"]
      access_control_max_age_sec = 600
      origin_override = false
    }
    
    custom_headers = [
      {
        header   = "X-Frame-Options"
        value    = "DENY"
        override = true
      },
      {
        header   = "X-Content-Type-Options"
        value    = "nosniff"
        override = true
      },
      {
        header   = "Referrer-Policy"
        value    = "strict-origin-when-cross-origin"
        override = true
      }
    ]
    
    security_headers = {
      strict_transport_security = {
        access_control_max_age_sec = 31536000
        include_subdomains = true
        preload = true
        override = true
      }
      
      content_type_options = {
        override = true
      }
      
      frame_options = {
        frame_option = "DENY"
        override = true
      }
      
      referrer_policy = {
        referrer_policy = "strict-origin-when-cross-origin"
        override = true
      }
    }
  }
  
  # WAF integration
  web_acl_id = aws_wafv2_web_acl.main.arn
  
  # Logging
  logging_config = {
    bucket          = aws_s3_bucket.cloudfront_logs.bucket_domain_name
    include_cookies = false
    prefix          = "cloudfront-logs/"
  }
  
  # Error pages
  custom_error_responses = [
    {
      error_code         = 404
      response_code      = 404
      response_page_path = "/404.html"
      error_caching_min_ttl = 300
    },
    {
      error_code         = 500
      response_code      = 500
      response_page_path = "/500.html"
      error_caching_min_ttl = 0
    }
  ]
  
  tags = {
    Environment = "prod"
    Project     = "nextjs-infrastructure"
    Security    = "high"
  }
}
```

### Environment-Specific Examples

#### Development Environment
```hcl
module "cloudfront_dev" {
  source = "../../../modules/cloudfront"
  
  environment = "dev"
  domain_name = "dev.placeholder.mx"
  
  s3_bucket_id                = module.s3_website_dev.bucket_id
  s3_bucket_regional_domain_name = module.s3_website_dev.bucket_regional_domain_name
  acm_certificate_arn = module.route53_acm.certificate_arn
  
  # Cost optimization for dev
  price_class = "PriceClass_100"  # Regional only
  
  # Simple cache behaviors for dev
  cache_behaviors = [
    {
      path_pattern     = "*"
      target_origin_id = "S3-Website"
      
      # Short cache for development
      default_ttl = 300   # 5 minutes
      max_ttl     = 3600  # 1 hour
      min_ttl     = 0
      
      headers = []
      query_string = false
      compress = true
      viewer_protocol_policy = "redirect-to-https"
    }
  ]
  
  # No logging in dev to save costs
  logging_config = null
  
  tags = {
    Environment = "dev"
    CostOptimized = "true"
  }
}
```

## Module Integration Examples

### Complete Environment Setup

```hcl
# Complete development environment
module "dev_environment" {
  # Cognito for authentication
  cognito = module.cognito_dev
  
  # S3 buckets
  s3_website = module.s3_website_dev
  s3_content = module.s3_content_dev
  
  # DNS and certificates (shared)
  route53_acm = module.route53_acm_shared
  
  # CloudFront distribution
  cloudfront = module.cloudfront_dev
}

# Output important values
output "dev_environment" {
  value = {
    # Authentication
    user_pool_id     = module.cognito_dev.user_pool_id
    user_pool_client_id = module.cognito_dev.user_pool_client_id
    
    # Storage
    website_bucket   = module.s3_website_dev.bucket_id
    content_bucket   = module.s3_content_dev.bucket_id
    
    # Distribution
    cloudfront_domain = module.cloudfront_dev.domain_name
    website_url      = "https://dev.placeholder.mx"
  }
  
  sensitive = false
}
```

### Cross-Module Dependencies

```hcl
# Dependencies are handled automatically through outputs/inputs
locals {
  # CloudFront depends on S3 and Route53/ACM
  cloudfront_dependencies = {
    s3_bucket_id = module.s3_website.bucket_id
    s3_domain    = module.s3_website.bucket_regional_domain_name
    certificate  = module.route53_acm.certificate_arn
  }
  
  # Application configuration depends on all modules
  app_config = {
    auth = {
      user_pool_id = module.cognito.user_pool_id
      client_id    = module.cognito.user_pool_client_id
      region       = var.aws_region
    }
    
    storage = {
      website_bucket = module.s3_website.bucket_id
      content_bucket = module.s3_content.bucket_id
      region         = var.aws_region
    }
    
    cdn = {
      distribution_id = module.cloudfront.distribution_id
      domain_name     = module.cloudfront.domain_name
    }
  }
}

# Export configuration for application
resource "local_file" "app_config" {
  content = jsonencode(local.app_config)
  filename = "${path.module}/app-config.json"
}
```

This comprehensive module usage guide provides all the necessary examples and configurations for effectively using the custom Terraform modules in your Next.js infrastructure project.