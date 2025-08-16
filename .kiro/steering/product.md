# Product Overview

## Terraform Next.js Infrastructure

A comprehensive Infrastructure as Code (IaC) solution for deploying scalable, cost-effective web application infrastructure on AWS specifically designed for Next.js applications.

### Core Purpose
- **Static Website Hosting**: S3 + CloudFront for Next.js static builds
- **User Authentication**: AWS Cognito for secure user management  
- **Secure Content Delivery**: Private S3 buckets with presigned URL access
- **Multi-Environment Support**: Separate dev and prod environments with cost optimization
- **Ultra-Low Cost Monitoring**: Essential monitoring for ~$0.60/month (dev), ~$6.80/month (prod)

### Key Features
- **Cost-Optimized**: Estimated monthly costs for low traffic: ~$15-25 (dev), ~$35-55 (prod)
- **Security-First**: Encryption at rest/transit, IAM least privilege, automated security scanning
- **Modular Architecture**: Reusable Terraform modules for each service
- **Environment-Specific**: Different optimization strategies for dev vs prod
- **Easy CI/CD**: Automated GitHub Actions pipelines with simple workflows
- **Simple Deployment**: Push to deploy, no complex commands needed

### Target Use Cases
- Next.js applications requiring AWS hosting
- Projects needing user authentication with Cognito
- Applications with private content requiring secure access
- Cost-conscious deployments with monitoring requirements
- Multi-environment development workflows
- Teams wanting simple, automated infrastructure deployment
- Developers who prefer CI/CD over manual infrastructure management

### Deployment Philosophy
- **Simplicity First**: No complex testing frameworks or commands
- **Automation by Default**: Push to deploy, CI/CD handles the rest
- **Security Built-in**: Automated security scanning on every change
- **Developer Friendly**: Clear documentation and easy workflows
- **Production Ready**: Approval gates and safety checks for production