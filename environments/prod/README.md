# Production Environment

This directory contains the Terraform configuration for the production environment of the Next.js infrastructure project.

## Overview

The production environment is configured with enhanced security, compliance, and monitoring features suitable for production workloads. It includes:

- **Enhanced Security**: MFA enabled, stricter password policies, HTTPS-only configurations
- **Compliance Features**: Advanced security mode, comprehensive tagging, audit logging
- **Production-Grade Monitoring**: Cost alerts, security monitoring, enhanced logging
- **Backup and Recovery**: Versioning enabled, lifecycle policies, retention management

## Configuration Files

- `main.tf` - Main Terraform configuration that instantiates all modules
- `variables.tf` - Variable definitions with validation rules
- `terraform.tfvars` - Default variable values for production
- `outputs.tf` - Output values from all modules
- `versions.tf` - Terraform and provider version constraints
- `backend.tf` - Backend configuration for state management (to be created)

## Key Production Features

### Security Enhancements
- **Cognito MFA**: Enabled by default (`cognito_mfa_configuration = "ON"`)
- **Password Policy**: 12-character minimum with all character types required
- **Advanced Security**: Enforced mode for additional protection
- **HTTPS Only**: All URLs and origins must use HTTPS
- **Token Validity**: Shorter token lifespans for enhanced security

### Compliance and Governance
- **Data Classification**: Marked as "confidential"
- **Compliance**: Required compliance mode
- **Comprehensive Tagging**: Enhanced tagging for governance and cost tracking
- **Backup Requirements**: Enabled with 30-day retention

### Cost Optimization
- **S3 Lifecycle Policies**: Automatic transition to cheaper storage classes
- **CloudFront Optimization**: PriceClass_100 for cost-effective global distribution
- **Intelligent Monitoring**: Cost alerts at $25/month and $2/day thresholds
- **Resource Optimization**: Versioning and lifecycle management enabled

### Monitoring and Alerting
- **Cost Monitoring**: Automated alerts for budget thresholds
- **Log Retention**: 30-day retention for CloudWatch logs
- **Enhanced Tagging**: Monitoring level set to "enhanced"
- **Alert Configuration**: Email alerts to alerts@placeholder.mx

## Environment Variables

The production environment uses variables from `config/prod.env` which are loaded by the deployment script. Key production-specific settings include:

```bash
# Security Settings
COGNITO_MFA_CONFIGURATION=ON
COGNITO_MIN_PASSWORD_LENGTH=12
COGNITO_REQUIRE_SYMBOLS=true
COGNITO_ADVANCED_SECURITY_MODE=ENFORCED

# Domain Configuration
DOMAIN_NAME=placeholder.mx
ROOT_DOMAIN=placeholder.mx
ROUTE53_CREATE_HOSTED_ZONE=true

# Storage Configuration
S3_ENABLE_VERSIONING=true
S3_ENABLE_SERVER_SIDE_ENCRYPTION=true
S3_PRESIGNED_URL_EXPIRATION_SECONDS=900

# Monitoring Configuration
MONITORING_ENABLE_COST_ALERTS=true
MONITORING_MONTHLY_COST_THRESHOLD=25
MONITORING_DAILY_COST_THRESHOLD=2
```

## Deployment

### Prerequisites
1. AWS credentials configured with appropriate permissions
2. Terraform >= 1.0 installed
3. Environment variables loaded from `config/prod.env`

### Deployment Commands

Using the deployment script (recommended):
```bash
# From project root
./scripts/deploy.sh prod plan    # Review changes
./scripts/deploy.sh prod apply   # Deploy infrastructure
```

Manual deployment:
```bash
# Load environment variables
source config/common.env
source config/prod.env

# Navigate to production environment
cd environments/prod

# Initialize and deploy
terraform init
terraform plan
terraform apply
```

### State Management

The production environment uses S3 backend for state management with:
- **State Bucket**: `terraform-nextjs-infrastructure-tfstate-${AWS_ACCOUNT_ID}-us-east-1`
- **State Key**: `prod/terraform.tfstate`
- **Lock Table**: `terraform-nextjs-infrastructure-tfstate-lock`
- **Encryption**: Enabled

## Security Considerations

### Access Control
- All resources use least-privilege IAM policies
- Cognito configured with strict authentication requirements
- S3 buckets have public access blocked by default
- CloudFront uses Origin Access Control for secure S3 access

### Data Protection
- Server-side encryption enabled for all S3 buckets
- KMS encryption using AWS managed keys
- Versioning enabled for data recovery
- Lifecycle policies for cost-effective retention

### Network Security
- HTTPS enforced for all web traffic
- CloudFront configured with security headers
- CORS policies restricted to production domains
- Geographic restrictions available if needed

## Monitoring and Maintenance

### Cost Monitoring
- Monthly budget alert at $25
- Daily spending alert at $2
- Automatic lifecycle policies to reduce storage costs
- Regular cost optimization reviews recommended

### Performance Monitoring
- CloudFront distribution metrics
- S3 bucket access patterns
- Cognito authentication metrics
- Custom CloudWatch dashboards (optional)

### Backup and Recovery
- S3 versioning enabled for data recovery
- 30-day retention for non-current versions
- Cross-region replication available (currently disabled)
- Point-in-time recovery options available

## Troubleshooting

### Common Issues
1. **Certificate Validation**: Ensure DNS records are properly configured
2. **Cognito Configuration**: Verify callback URLs match application settings
3. **S3 Permissions**: Check bucket policies and IAM roles
4. **CloudFront Caching**: Clear cache if content updates aren't visible

### Support Contacts
- **Technical Issues**: platform-team
- **Security Concerns**: security@placeholder.mx
- **Cost Optimization**: alerts@placeholder.mx

## Compliance and Auditing

### Audit Trail
- CloudTrail logging enabled for all API calls
- CloudWatch logs retained for 30 days
- Resource tagging for compliance tracking
- Regular security assessments recommended

### Compliance Features
- Data classification tagging
- Backup requirement enforcement
- Security mode enforcement
- Comprehensive resource tagging

For more information, see the main project documentation in the `docs/` directory.