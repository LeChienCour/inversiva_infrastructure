# Terraform Next.js Infrastructure

A comprehensive Infrastructure as Code (IaC) solution using Terraform and Terragrunt to deploy a scalable, cost-effective web application infrastructure on AWS for Next.js applications.

## 🏗️ Architecture Overview

This infrastructure supports:
- **Next.js Frontend**: Static website hosting with S3 and CloudFront
- **User Authentication**: AWS Cognito for secure user management
- **Content Delivery**: Global CDN with custom domain support
- **Secure Content**: Private S3 buckets with presigned URL access
- **Multi-Environment**: Separate dev and prod environments
- **Cost Optimization**: Environment-appropriate resource sizing

## 📁 Project Structure

```
├── bootstrap/                 # Bootstrap infrastructure for state management
│   ├── main.tf               # S3 bucket and DynamoDB table for Terraform state
│   ├── variables.tf          # Bootstrap variables
│   ├── outputs.tf            # Bootstrap outputs
│   ├── bootstrap.sh          # Bootstrap script (Linux/macOS)
│   ├── bootstrap.ps1         # Bootstrap script (Windows)
│   └── README.md             # Bootstrap documentation
├── environments/             # Environment-specific configurations
│   ├── dev/                  # Development environment
│   └── prod/                 # Production environment
├── modules/                  # Custom Terraform modules
│   ├── cognito/              # Cognito authentication module
│   ├── s3-website/           # S3 static website hosting module
│   ├── s3-content/           # S3 private content storage module
│   └── cloudfront/           # CloudFront distribution module
├── terragrunt.hcl            # Root Terragrunt configuration
├── .gitignore                # Git ignore patterns
└── README.md                 # This file
```

## 🚀 Quick Start

### Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** (>= 1.0)
3. **Terragrunt** (>= 0.45.0)
4. **Git** for version control

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd terraform-nextjs-infrastructure
   ```

2. **Bootstrap the state infrastructure**
   ```bash
   cd bootstrap
   ./bootstrap.sh  # Linux/macOS
   # or
   .\bootstrap.ps1  # Windows PowerShell
   ```

3. **Deploy an environment**
   ```bash
   cd environments/dev
   terragrunt run-all plan    # Review changes
   terragrunt run-all apply   # Deploy infrastructure
   ```

## 🏛️ Infrastructure Components

### Core Services

- **S3 Buckets**: Static website hosting and private content storage
- **CloudFront**: Global CDN with custom domain support
- **Cognito**: User authentication and authorization
- **Route 53**: DNS management and domain routing
- **ACM**: SSL/TLS certificate management

### Security Features

- Server-side encryption for all S3 buckets
- Private content access via presigned URLs
- OAuth2/OIDC authentication flows
- Least privilege IAM policies
- Public access blocking on private resources

### Cost Optimization

- Environment-appropriate resource sizing
- S3 lifecycle policies for storage cost reduction
- CloudFront caching strategies
- Pay-per-request DynamoDB billing
- Regional vs global CloudFront distributions

## 🌍 Environment Management

### Development Environment
- Cost-optimized resources
- Relaxed security policies for development
- Regional CloudFront distribution
- Standard-IA storage classes

### Production Environment
- Performance-optimized resources
- Enhanced security features
- Global CloudFront distribution
- Standard storage classes with lifecycle policies

## 📋 Requirements Addressed

This infrastructure addresses the following key requirements:

1. **Multi-Environment Support** (Requirements 1.1, 1.4)
   - Separate dev and prod environments
   - Terragrunt-based selective deployment
   - S3-based state management within the same AWS account

2. **Static Website Hosting** (Requirements 2.1-2.4)
   - S3 static website hosting for Next.js builds
   - CloudFront CDN for global performance
   - Custom domain support with SSL certificates
   - Cache invalidation capabilities

3. **User Authentication** (Requirements 3.1-3.4)
   - AWS Cognito User Pool integration
   - OAuth2/OIDC support for frontend applications
   - Secure token-based authentication

4. **Secure Content Delivery** (Requirements 4.1-4.4)
   - Private S3 buckets for content storage
   - Presigned URL generation with access controls
   - Server-side encryption and security policies

5. **Modular Architecture** (Requirement 5.1)
   - Custom Terraform modules for each service
   - Reusable components with proper documentation
   - Separation of concerns between services

## 🔧 Development Workflow

### Making Changes

1. **Plan changes**
   ```bash
   cd environments/dev
   terragrunt plan
   ```

2. **Apply changes**
   ```bash
   terragrunt apply
   ```

3. **Deploy to production**
   ```bash
   cd ../prod
   terragrunt plan
   terragrunt apply
   ```

### Module Development

1. Create or modify modules in the `modules/` directory
2. Test changes in the dev environment first
3. Update module documentation and examples
4. Deploy to production after validation

## 📊 Monitoring and Maintenance

### State Management
- Terraform state stored in S3 with versioning
- DynamoDB table for state locking
- Automatic state backup and recovery

### Cost Monitoring
- S3 lifecycle policies for cost optimization
- CloudFront caching for reduced origin requests
- Environment-appropriate resource sizing

### Security Monitoring
- All resources encrypted at rest and in transit
- IAM policies following least privilege principle
- Regular security scanning with Checkov

## 🆘 Troubleshooting

### Common Issues

1. **State locking errors**
   - Check DynamoDB table permissions
   - Verify state bucket access

2. **Module not found errors**
   - Ensure module paths are correct in terragrunt.hcl
   - Verify module structure and files

3. **AWS permission errors**
   - Check IAM policies and permissions
   - Verify AWS CLI configuration

### Getting Help

1. Check the bootstrap README for initial setup issues
2. Review Terragrunt logs for detailed error messages
3. Validate Terraform syntax with `terraform validate`
4. Use `terragrunt plan` to preview changes before applying

## 🤝 Contributing

1. Create feature branches for changes
2. Test changes in dev environment first
3. Update documentation for any new features
4. Follow Terraform and Terragrunt best practices

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🔗 Related Documentation

- [Terraform Documentation](https://www.terraform.io/docs)
- [Terragrunt Documentation](https://terragrunt.gruntwork.io/docs)
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Next.js Deployment Guide](https://nextjs.org/docs/deployment)