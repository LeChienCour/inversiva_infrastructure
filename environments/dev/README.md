# Development Environment

This directory contains the Terraform configuration for the development environment of the Next.js infrastructure project.

## Overview

The development environment is optimized for cost and development speed, with relaxed security settings and regional CloudFront distribution.

## Configuration Files

- `main.tf` - Main Terraform configuration that instantiates all modules
- `variables.tf` - Variable definitions with validation rules
- `outputs.tf` - Output values from all modules
- `terraform.tfvars` - Default variable values for development
- `backend.tf` - S3 backend configuration for state management
- `versions.tf` - Terraform and provider version constraints

## Deployed Resources

### Core Infrastructure
- **Route53 & ACM**: DNS management and SSL certificates
- **Cognito**: User authentication (User Pool + Identity Pool)
- **S3 Website**: Static website hosting bucket
- **S3 Content**: Private content storage bucket
- **CloudFront**: CDN distribution
- **Monitoring**: CloudWatch dashboards and alarms

### Development-Specific Settings
- **Cost Optimization**: PriceClass_100 for CloudFront (US, Canada, Europe)
- **Relaxed Security**: Optional MFA, shorter token validity
- **Local Development**: CORS configured for localhost:3000
- **Minimal Monitoring**: Basic CloudWatch monitoring only

## Environment Variables

Configuration is managed through environment variables loaded from:
- `config/common.env` - Shared configuration
- `config/dev.env` - Development-specific configuration

Key development settings:
- Domain: `dev.placeholder.mx`
- Cognito password length: 8 characters minimum
- S3 versioning: Disabled for cost savings
- CloudFront price class: PriceClass_100
- Route53 hosted zone: Not created (assumes existing)

## Deployment

### Prerequisites
1. AWS credentials configured
2. Terraform >= 1.0 installed
3. Bootstrap infrastructure deployed (S3 bucket + DynamoDB table)

### Deploy Command
```bash
# From project root
./scripts/deploy.sh dev plan    # Review changes
./scripts/deploy.sh dev apply   # Deploy infrastructure
```

### Manual Deployment
```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

## Outputs

After deployment, the following outputs are available:
- Application URL: `https://dev.placeholder.mx`
- Cognito User Pool ID
- S3 bucket names
- CloudFront distribution ID
- Certificate ARN

## Dependencies

Modules are deployed in the following order:
1. Route53 & ACM (certificates)
2. S3 buckets (website and content)
3. CloudFront (CDN distribution)
4. Cognito (authentication)
5. Monitoring (CloudWatch)

## Cost Estimation

Estimated monthly costs for low traffic development environment:
- CloudFront: ~$1-3
- S3: ~$1-2
- Route53: ~$0.50
- Cognito: Free tier
- CloudWatch: ~$0.60
- **Total: ~$3-6/month**

## Security Notes

Development environment uses relaxed security settings:
- MFA is optional
- Shorter token validity periods
- CORS allows localhost origins
- No advanced security features enabled

For production deployment, see `../prod/` directory.