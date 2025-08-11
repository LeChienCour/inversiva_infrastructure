# Development Environment Deployment Guide

This directory contains the Terragrunt configuration for the development environment of the Inversiva infrastructure project.

## Architecture Overview

The development environment is optimized for cost savings while maintaining functionality for testing and development purposes.

## Deployment Order

Due to interdependencies between modules, deploy them in the following order:

### Phase 1: Foundation
1. **route53-acm** - Creates domain certificates and DNS records
2. **cognito** - Creates user authentication infrastructure

### Phase 2: Storage and Distribution
3. **cloudfront** - Creates CDN distribution (requires certificate from route53-acm)
4. **s3-website** - Creates website hosting bucket
5. **s3-content** - Creates private content bucket (requires cognito for IAM policies)

### Phase 3: Integration
After all modules are deployed, you may need to update configurations to wire them together:
- Update S3 website bucket policy with CloudFront OAC
- Update Cognito IAM policies with S3 content bucket ARN
- Update CloudFront origin with actual S3 bucket domain

## Cost Optimizations

The development environment includes several cost optimizations:

### S3 Optimizations
- Versioning disabled to save storage costs
- Aggressive lifecycle policies (IA after 7 days, Glacier after 30 days)
- No access logging to reduce costs

### CloudFront Optimizations
- PriceClass_100 (North America and Europe only)
- IPv6 disabled
- Monitoring disabled
- No WAF integration

### Route53 Optimizations
- Uses existing hosted zone (saves $0.50/month)
- Health checks disabled (saves $0.50/month)
- IPv6 records disabled

### Cognito Optimizations
- MFA optional instead of required
- Relaxed password policies
- Shorter token validity periods

## Environment Variables

Key environment-specific variables:
- Domain: `dev.placeholder.mx`
- Environment: `dev`
- Cost optimization: Enabled
- Auto-shutdown: Enabled for applicable resources

## Deployment Commands

Deploy individual modules:
```bash
# Deploy in order
cd route53-acm && terragrunt apply
cd ../cognito && terragrunt apply
cd ../cloudfront && terragrunt apply
cd ../s3-website && terragrunt apply
cd ../s3-content && terragrunt apply
```

Deploy all modules (use with caution due to dependencies):
```bash
terragrunt run-all apply
```

## Testing

After deployment, verify:
1. Domain resolves to CloudFront distribution
2. S3 website bucket serves content through CloudFront
3. Cognito user pool is accessible
4. S3 content bucket generates presigned URLs
5. All resources are properly tagged

## Cleanup

To destroy the environment:
```bash
terragrunt run-all destroy
```

Note: Destroy in reverse order if doing manually to avoid dependency issues.