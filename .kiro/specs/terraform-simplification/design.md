# Design Document

## Overview

This design restructures the existing Terragrunt-based infrastructure to use pure Terraform with environment-specific `.env` files. The new architecture eliminates Terragrunt complexity while maintaining all AWS functionality through a simplified directory structure and environment variable management.

## Architecture

### High-Level Structure

```
├── environments/
│   ├── dev/
│   │   ├── main.tf              # Main Terraform configuration
│   │   ├── variables.tf         # Variable definitions
│   │   ├── outputs.tf           # Output values
│   │   ├── terraform.tfvars     # Default values
│   │   └── backend.tf           # Backend configuration
│   └── prod/
│       ├── main.tf              # Main Terraform configuration
│       ├── variables.tf         # Variable definitions
│       ├── outputs.tf           # Output values
│       ├── terraform.tfvars     # Default values
│       └── backend.tf           # Backend configuration
├── modules/                     # Existing modules (unchanged)
│   ├── cognito/
│   ├── s3-website/
│   ├── s3-content/
│   ├── cloudfront/
│   ├── route53-acm/
│   └── monitoring/
├── config/
│   ├── dev.env                  # Development environment variables
│   ├── prod.env                 # Production environment variables
│   └── common.env               # Shared environment variables
├── scripts/
│   ├── deploy.sh                # Deployment script
│   └── load-env.sh              # Environment loading utility
├── bootstrap/                   # State management (unchanged)
└── README.md                    # Updated documentation
```

### Environment Variable Strategy

Environment-specific configurations will be managed through `.env` files that are loaded before Terraform execution:

**config/common.env** - Shared variables:
```bash
PROJECT_NAME=terraform-nextjs-infrastructure
AWS_REGION=us-east-1
TERRAFORM_VERSION_CONSTRAINT=">= 1.0"
AWS_PROVIDER_VERSION="~> 5.0"
RANDOM_PROVIDER_VERSION="~> 3.1"
```

**config/dev.env** - Development-specific:
```bash
ENVIRONMENT=dev
DOMAIN_NAME=dev.placeholder.mx
ROOT_DOMAIN=placeholder.mx
COGNITO_MIN_PASSWORD_LENGTH=8
COGNITO_REQUIRE_SYMBOLS=false
COGNITO_TEMP_PASSWORD_VALIDITY=7
S3_CONTENT_BUCKET_PREFIX=inversiva-dev-content
ROUTE53_CREATE_HOSTED_ZONE=false
CLOUDFRONT_PRICE_CLASS=PriceClass_100
S3_ENABLE_VERSIONING=false
CORS_ALLOW_ORIGINS=["http://localhost:3000","https://dev.placeholder.mx"]
```

**config/prod.env** - Production-specific:
```bash
ENVIRONMENT=prod
DOMAIN_NAME=placeholder.mx
ROOT_DOMAIN=placeholder.mx
COGNITO_MIN_PASSWORD_LENGTH=12
COGNITO_REQUIRE_SYMBOLS=true
COGNITO_TEMP_PASSWORD_VALIDITY=3
S3_CONTENT_BUCKET_PREFIX=inversiva-prod-content
ROUTE53_CREATE_HOSTED_ZONE=true
CLOUDFRONT_PRICE_CLASS=PriceClass_All
S3_ENABLE_VERSIONING=true
CORS_ALLOW_ORIGINS=["https://placeholder.mx"]
```

## Components and Interfaces

### Environment Directories

Each environment (`dev`, `prod`) will contain complete Terraform configurations that reference the shared modules:

**main.tf** - Module instantiation:
```hcl
module "cognito" {
  source = "../../modules/cognito"
  # Variables passed from terraform.tfvars
}

module "s3_website" {
  source = "../../modules/s3-website"
  # Variables passed from terraform.tfvars
}

# Additional modules...
```

**variables.tf** - Variable definitions with validation:
```hcl
variable "environment" {
  description = "Environment name"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be either 'dev' or 'prod'."
  }
}

variable "domain_name" {
  description = "Primary domain name"
  type        = string
}

# Additional variables...
```

**terraform.tfvars** - Environment-specific values loaded from .env:
```hcl
environment = "dev"
domain_name = "dev.placeholder.mx"
# Values populated by deployment script from .env files
```

### Deployment Script

A shell script will handle environment loading and Terraform execution:

```bash
#!/bin/bash
# scripts/deploy.sh

ENVIRONMENT=$1
ACTION=$2

# Load environment variables
source config/common.env
source config/${ENVIRONMENT}.env

# Navigate to environment directory
cd environments/${ENVIRONMENT}

# Generate terraform.tfvars from environment variables
# Execute Terraform commands
terraform init
terraform ${ACTION}
```

### State Management

Each environment will have its own backend configuration:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-nextjs-infrastructure-tfstate-${AWS_ACCOUNT_ID}-us-east-1"
    key            = "${ENVIRONMENT}/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-nextjs-infrastructure-tfstate-lock"
    encrypt        = true
  }
}
```

## Data Models

### Environment Configuration Model

```hcl
# Environment configuration structure
locals {
  environment_config = {
    environment = var.environment
    domain_name = var.domain_name
    root_domain = var.root_domain
    
    cognito_config = {
      password_policy = {
        minimum_length                   = var.cognito_min_password_length
        require_lowercase               = true
        require_numbers                 = true
        require_symbols                 = var.cognito_require_symbols
        require_uppercase               = true
        temporary_password_validity_days = var.cognito_temp_password_validity
      }
    }
    
    s3_config = {
      content_bucket_prefix = var.s3_content_bucket_prefix
      enable_versioning     = var.s3_enable_versioning
    }
    
    cloudfront_config = {
      price_class = var.cloudfront_price_class
    }
    
    route53_config = {
      create_hosted_zone = var.route53_create_hosted_zone
    }
    
    cors_config = {
      allow_origins = var.cors_allow_origins
    }
  }
}
```

### Module Interface Standardization

All modules will receive a standardized configuration object:

```hcl
module "example" {
  source = "../../modules/example"
  
  project_name     = var.project_name
  environment      = var.environment
  aws_region       = var.aws_region
  common_tags      = local.common_tags
  environment_config = local.environment_config
}
```

## Error Handling

### Environment Validation

- Validate environment parameter before execution
- Check for required environment variables
- Verify .env file existence and format
- Validate Terraform configuration syntax

### Deployment Safety

- Implement plan-before-apply workflow
- Add confirmation prompts for production deployments
- Validate state file accessibility
- Check AWS credentials and permissions

### Rollback Strategy

- Maintain Terraform state backups
- Document rollback procedures
- Implement state file versioning
- Provide emergency recovery scripts

## Testing Strategy

### Configuration Testing

- Validate Terraform syntax with `terraform validate`
- Test variable interpolation and defaults
- Verify module compatibility
- Check provider version constraints

### Environment Testing

- Test deployment script with dry-run mode
- Validate environment variable loading
- Test both dev and prod configurations
- Verify state management functionality

### Integration Testing

- Deploy to development environment
- Validate all AWS resources creation
- Test cross-module dependencies
- Verify outputs and data sources

### Security Testing

- Continue using Checkov for security scanning
- Validate IAM permissions and policies
- Test encryption configurations
- Verify network security settings