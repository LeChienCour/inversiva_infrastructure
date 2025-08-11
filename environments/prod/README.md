# Production Environment

This directory contains the production environment configuration for the Terraform Next.js infrastructure project.

## Overview

The production environment is configured with enterprise-grade security, global performance optimization, and comprehensive monitoring. It implements strict security policies, enhanced backup procedures, and operational excellence practices.

## Key Features

### 🔒 Security
- **MFA Required**: Multi-factor authentication enforced for all users
- **Advanced Threat Protection**: Cognito advanced security mode enabled
- **Strict Password Policies**: 12-character minimum with symbols required
- **Enhanced Encryption**: Server-side encryption with KMS integration
- **Public Access Blocked**: All S3 buckets have public access completely blocked
- **Security Headers**: Comprehensive security headers via CloudFront

### ⚡ Performance
- **Global CDN**: CloudFront distribution with worldwide edge locations
- **Intelligent Tiering**: S3 automatic cost optimization
- **Enhanced Caching**: Optimized TTL values for production workloads
- **IPv6 Support**: Modern protocol support for better connectivity
- **Health Checks**: Multi-region health monitoring

### 📊 Monitoring & Observability
- **CloudWatch Integration**: Full monitoring and alerting
- **Access Logging**: Comprehensive audit trails
- **Cost Monitoring**: Automated budget alerts and thresholds
- **Performance Metrics**: Real-time performance monitoring
- **Security Alerts**: Automated security event notifications

## Directory Structure

```
environments/prod/
├── terragrunt.hcl              # Main production configuration
├── cognito/
│   └── terragrunt.hcl         # Cognito User Pool configuration
├── s3-content/
│   └── terragrunt.hcl         # Private content S3 bucket
├── s3-website/
│   └── terragrunt.hcl         # Static website S3 bucket
├── cloudfront/
│   └── terragrunt.hcl         # CloudFront distribution
├── route53-acm/
│   └── terragrunt.hcl         # DNS and SSL certificate
├── CONFIGURATION_APPROACH.md   # Detailed configuration documentation
└── README.md                   # This file
```

## Configuration Highlights

### Domain Configuration
- **Primary Domain**: `placeholder.mx`
- **SSL Certificate**: ACM certificate with DNS validation
- **Health Checks**: Multi-region health monitoring enabled

### Security Configuration
```hcl
# Enhanced security settings
mfa_configuration = "ON"
advanced_security_mode = "ENFORCED"
password_policy = {
  minimum_length = 12
  require_symbols = true
}
```

### Performance Configuration
```hcl
# Global performance optimization
price_class = "PriceClass_All"
enable_intelligent_tiering = true
default_ttl = 86400  # 1 day caching
```

## Deployment

### Prerequisites
1. AWS CLI configured with production account credentials
2. Terragrunt installed
3. Terraform installed
4. Proper IAM permissions for production resources

### Deployment Order
The modules should be deployed in the following order due to dependencies:

1. **Route53 & ACM** - DNS and SSL certificate
2. **S3 Website** - Static website hosting
3. **S3 Content** - Private content storage
4. **Cognito** - User authentication
5. **CloudFront** - CDN distribution

### Deploy All Modules
```bash
# From the prod directory
cd environments/prod
terragrunt run-all plan
terragrunt run-all apply
```

### Deploy Individual Modules
```bash
# Deploy specific module
cd environments/prod/cognito
terragrunt plan
terragrunt apply
```

## Cost Optimization

### Monitoring
- **Monthly Budget**: $25 USD threshold (optimized for small apps)
- **Daily Budget**: $2 USD threshold (realistic for 20 users)
- **Automated Alerts**: Email notifications for cost overruns

### Optimization Features
- **Regional CloudFront**: PriceClass_100 for 60% cost savings vs global
- **Aggressive Lifecycle Policies**: Quick transitions (7/30/30 days)
- **Disabled Monitoring**: Reduced CloudWatch costs for small usage
- **No Health Checks**: Saves $1.50/month
- **No Access Logging**: Eliminates logging storage costs
- **AWS Managed KMS**: Free encryption keys instead of custom KMS
- **CloudFront Caching**: Aggressive caching to reduce origin requests
- **Resource Tagging**: Comprehensive cost allocation tags

## Security Compliance

### Data Protection
- **Encryption at Rest**: All S3 buckets encrypted with KMS
- **Encryption in Transit**: TLS 1.2+ enforced
- **Access Controls**: Principle of least privilege
- **Audit Logging**: Comprehensive access and event logging

### Compliance Features
- **Object Lock**: Immutable storage for compliance
- **Versioning**: Full version history for data recovery
- **Cross-Region Backup**: Disaster recovery capabilities
- **Security Scanning**: Automated policy validation

## Monitoring & Alerting

### CloudWatch Metrics
- **Error Rates**: < 5% threshold
- **Latency**: < 5 second threshold
- **Availability**: 99.9% uptime target
- **Cost**: Budget threshold monitoring

### Alert Channels
- **Email**: `alerts@placeholder.mx`
- **SNS Topics**: Automated notification system
- **CloudWatch Dashboards**: Real-time monitoring

## Troubleshooting

### Common Issues

#### Certificate Validation
If ACM certificate validation fails:
```bash
# Check DNS records
dig TXT _acme-challenge.placeholder.mx
```

#### CloudFront Distribution
If CloudFront deployment fails:
```bash
# Check origin access
aws s3 ls s3://inversiva-prod-website/
```

#### Cognito Configuration
If user authentication fails:
```bash
# Check user pool configuration
aws cognito-idp describe-user-pool --user-pool-id <pool-id>
```

### Support
For production issues, contact the platform team immediately:
- **Email**: platform-team@placeholder.mx
- **Slack**: #platform-alerts
- **On-call**: Follow escalation procedures

## Maintenance

### Regular Tasks
- **Monthly**: Review cost reports and optimization opportunities
- **Quarterly**: Security policy review and updates
- **Annually**: Disaster recovery testing and documentation updates

### Backup Verification
- **Weekly**: Verify backup integrity
- **Monthly**: Test restore procedures
- **Quarterly**: Full disaster recovery drill

## Security Contacts

For security incidents or concerns:
- **Security Team**: security@placeholder.mx
- **Incident Response**: Follow security incident procedures
- **Compliance**: compliance@placeholder.mx