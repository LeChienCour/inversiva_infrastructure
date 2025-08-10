# Development Environment Deployment Guide

This guide covers the automated deployment of infrastructure to the development environment using GitHub Actions and local development scripts.

## Overview

The development deployment workflow provides:

- **Automated Infrastructure Deployment**: Triggered by pushes to development branches
- **Pull Request Validation**: Validates changes before merging
- **Manual Component Deployment**: Deploy specific components on demand
- **Local Development Support**: Scripts for local testing and development
- **Security Scanning**: Automated security analysis with Checkov
- **Cost Optimization**: Development-specific resource configurations

## Quick Start

### 1. Repository Setup

1. **Configure GitHub Secrets**:
   ```
   AWS_ACCESS_KEY_ID: Your AWS access key
   AWS_SECRET_ACCESS_KEY: Your AWS secret key
   ```

2. **Set up GitHub Environments**:
   - Create `development` environment
   - Create `development-destroy` environment (optional, for destroy operations)

3. **Configure Branch Protection** (recommended):
   - Require pull request reviews for `develop` branch
   - Require status checks to pass

### 2. First Deployment

1. **Push to develop branch**:
   ```bash
   git checkout develop
   git push origin develop
   ```

2. **Monitor workflow**:
   - Go to Actions tab in GitHub
   - Watch "Deploy Development Environment" workflow
   - Review logs for any issues

3. **Verify deployment**:
   - Check AWS console for created resources
   - Review workflow outputs for resource details

## Workflow Triggers

### Automatic Triggers

1. **Push to Development Branches**:
   - `develop`
   - `dev`
   - `feature/*`

2. **Pull Request Validation**:
   - PRs to `develop` or `dev` branches
   - Runs validation and planning only

### Manual Triggers

1. **Manual Dispatch**:
   - Go to Actions → Deploy Development Environment
   - Select component and action
   - Click "Run workflow"

## Component Management

### Available Components

| Component | Description | Dependencies |
|-----------|-------------|--------------|
| `cognito` | User authentication | None |
| `s3-website` | Static website hosting | None |
| `s3-content` | Private content storage | None |
| `route53-acm` | DNS and SSL certificates | None |
| `cloudfront` | CDN distribution | s3-website, route53-acm |

### Deployment Order

Components are deployed in dependency order:
1. `cognito` - User authentication
2. `s3-website` - Website hosting bucket
3. `s3-content` - Private content bucket
4. `route53-acm` - DNS and SSL certificates
5. `cloudfront` - CDN distribution

### Selective Deployment

Deploy specific components using manual dispatch:

1. Go to Actions → Deploy Development Environment
2. Click "Run workflow"
3. Select component from dropdown
4. Choose action (plan/apply/destroy)
5. Click "Run workflow"

## Local Development

### Prerequisites

- Terraform >= 1.6.6
- Terragrunt >= 0.55.1
- AWS CLI configured
- Checkov (optional, for security scanning)

### Using the Development Script

#### Linux/macOS
```bash
# Plan all components
./scripts/dev-deploy.sh

# Apply specific component
./scripts/dev-deploy.sh -c cognito -a apply

# Plan with security scan skipped
./scripts/dev-deploy.sh --skip-security

# Destroy all components
./scripts/dev-deploy.sh -a destroy
```

#### Windows PowerShell
```powershell
# Plan all components
.\scripts\dev-deploy.ps1

# Apply specific component
.\scripts\dev-deploy.ps1 -Component cognito -Action apply

# Plan with security scan skipped
.\scripts\dev-deploy.ps1 -SkipSecurity

# Destroy all components
.\scripts\dev-deploy.ps1 -Action destroy
```

### Manual Terragrunt Commands

For advanced users who want to run Terragrunt directly:

```bash
cd environments/dev

# Initialize all components
terragrunt run-all init

# Plan all components
terragrunt run-all plan

# Apply all components
terragrunt run-all apply

# Apply specific component
cd cognito
terragrunt apply
```

## Security and Validation

### Automated Security Scanning

The workflow includes Checkov security scanning:

- **Scans**: All Terraform configurations
- **Reports**: Results uploaded to GitHub Security tab
- **Skipped Checks**: Development-specific exceptions
- **Failure Handling**: Warnings for non-critical issues

### Validation Steps

1. **Terraform Validation**: Syntax and configuration validation
2. **Terragrunt Validation**: Input validation and dependency checks
3. **Security Scan**: Checkov security analysis
4. **Plan Generation**: Terraform plan with change detection

### Security Best Practices

- AWS credentials stored as GitHub secrets
- Least privilege IAM permissions
- Encrypted Terraform state storage
- Private S3 buckets with proper access controls
- SSL/TLS certificates for all endpoints

## Cost Optimization

### Development-Specific Optimizations

- **S3 Storage**: Standard-IA for reduced costs
- **CloudFront**: Regional distribution (PriceClass_100)
- **Lifecycle Policies**: Aggressive cleanup of old versions
- **Resource Sizing**: Minimal configurations for testing

### Cost Monitoring

- **Budget Alerts**: Configured for development environment
- **Resource Tagging**: All resources tagged for cost tracking
- **Cleanup Scripts**: Automated cleanup of unused resources

## Troubleshooting

### Common Issues

#### 1. AWS Credentials Error
```
Error: Unable to locate credentials
```

**Solution**:
- Verify GitHub secrets are configured correctly
- Check IAM user permissions
- Ensure AWS region is correct

#### 2. Terragrunt Initialization Failure
```
Error: Failed to load backend
```

**Solution**:
- Verify S3 state bucket exists
- Check DynamoDB lock table
- Ensure proper IAM permissions for state management

#### 3. Security Scan Failures
```
Checkov found security issues
```

**Solution**:
- Review security scan results in GitHub Security tab
- Update configurations to fix issues
- Add skip checks for acceptable risks in development

#### 4. Component Dependencies
```
Error: Resource not found
```

**Solution**:
- Deploy components in correct order
- Check for missing dependencies
- Verify module outputs are available

### Debug Mode

Enable detailed logging:

1. **GitHub Actions**:
   - Set repository variable `ACTIONS_STEP_DEBUG` to `true`
   - Re-run workflow to see detailed logs

2. **Local Scripts**:
   - Add `-v` flag for verbose output
   - Check Terragrunt logs in `.terragrunt-cache`

### Getting Help

1. **Check Workflow Logs**: Review GitHub Actions logs for specific errors
2. **Local Testing**: Use development scripts to reproduce issues locally
3. **AWS Console**: Verify resource states in AWS console
4. **Terragrunt Cache**: Clear `.terragrunt-cache` directories if needed

## Advanced Configuration

### Custom Workflow Triggers

Add custom triggers to `.github/workflows/deploy-dev.yml`:

```yaml
on:
  schedule:
    - cron: '0 2 * * 1'  # Weekly deployment on Mondays at 2 AM
  repository_dispatch:
    types: [deploy-dev]   # API-triggered deployments
```

### Environment Variables

Customize deployment behavior with environment variables:

```yaml
env:
  TF_VAR_environment: development
  TF_VAR_cost_optimization: true
  TERRAGRUNT_PARALLELISM: 10
```

### Notification Integration

Add Slack notifications:

```yaml
- name: Notify Slack
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## Best Practices

### Development Workflow

1. **Feature Branches**: Create feature branches for new changes
2. **Pull Requests**: Use PRs for code review and validation
3. **Small Changes**: Make incremental changes for easier debugging
4. **Testing**: Test changes locally before pushing

### Infrastructure Management

1. **State Management**: Never modify Terraform state manually
2. **Resource Naming**: Follow consistent naming conventions
3. **Tagging**: Tag all resources for cost tracking and management
4. **Documentation**: Keep module documentation up to date

### Security Practices

1. **Secrets Management**: Use GitHub secrets for sensitive data
2. **Access Control**: Follow principle of least privilege
3. **Regular Scans**: Review security scan results regularly
4. **Updates**: Keep Terraform and Terragrunt versions updated

## Monitoring and Maintenance

### Regular Tasks

1. **Weekly**: Review cost reports and optimize resources
2. **Monthly**: Update Terraform and Terragrunt versions
3. **Quarterly**: Review and update security policies
4. **As Needed**: Clean up unused resources and old state files

### Metrics to Monitor

- **Deployment Success Rate**: Track workflow success/failure rates
- **Deployment Duration**: Monitor deployment times
- **Cost Trends**: Track monthly AWS costs
- **Security Issues**: Monitor security scan results

### Alerts and Notifications

Set up alerts for:
- Deployment failures
- Cost threshold breaches
- Security scan failures
- Resource quota limits

## Next Steps

1. **Production Deployment**: Set up production environment workflow
2. **Testing Framework**: Implement automated infrastructure testing
3. **Monitoring**: Set up comprehensive monitoring and alerting
4. **Documentation**: Create user guides for application developers