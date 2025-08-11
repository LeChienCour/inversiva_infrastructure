# GitHub Actions Workflows

This directory contains GitHub Actions workflows for automated deployment of the Terraform Next.js infrastructure.

## Workflows

### Development Deployment (`deploy-dev.yml`)

Automates the deployment of infrastructure to the development environment using Terragrunt.

### Production Deployment (`deploy-prod.yml`)

Automates the deployment of infrastructure to the production environment with enhanced security, manual approval gates, and rollback capabilities.

#### Development Triggers

1. **Push to development branches**:
   - `develop`
   - `dev` 
   - `feature/*`

2. **Pull requests** to development branches for validation

3. **Manual dispatch** with component and action selection

#### Production Triggers

1. **Push to production branches**:
   - `main`
   - `master`

2. **Manual dispatch** with component, action, and approval options

#### Development Workflow Jobs

1. **Validate**: Validates Terraform syntax and Terragrunt configuration
2. **Security Scan**: Runs Checkov security analysis
3. **Plan**: Generates Terragrunt execution plan
4. **Apply**: Applies infrastructure changes (conditional)
5. **Destroy**: Destroys infrastructure (manual only)

#### Production Workflow Jobs

1. **Validate**: Enhanced validation with failure notifications
2. **Security Scan**: Stricter security analysis for production
3. **Backup State**: Creates backup of current Terraform state
4. **Plan**: Generates detailed execution plan with artifacts
5. **Approval**: Manual approval gate for production deployments
6. **Apply**: Applies changes with verification and monitoring
7. **Rollback**: Automatic rollback on deployment failures
8. **Destroy**: Destroys infrastructure (manual only with extra protection)

#### Required Secrets

Configure these secrets in your GitHub repository settings:

- `AWS_ACCESS_KEY_ID`: AWS access key for deployment
- `AWS_SECRET_ACCESS_KEY`: AWS secret key for deployment
- `SLACK_WEBHOOK_URL` (optional): Slack webhook for production notifications

#### Environment Protection

The workflows use GitHub environments for additional security:

**Development Environments:**
- `development`: For plan and apply operations
- `development-destroy`: For destroy operations (requires additional approval)

**Production Environments:**
- `production-plan`: For planning operations
- `production-approval`: For manual approval gates
- `production`: For apply operations (requires approval)
- `production-rollback`: For rollback operations
- `production-destroy`: For destroy operations (requires multiple approvals)

#### Component Selection

You can deploy specific components using manual dispatch:

- `all` (default): Deploy all components
- `cognito`: User authentication
- `s3-website`: Static website hosting
- `s3-content`: Private content storage
- `cloudfront`: CDN distribution
- `route53-acm`: DNS and SSL certificates

#### Deployment Order

Components are deployed in dependency order:

1. `cognito` - User authentication
2. `s3-website` - Website hosting bucket
3. `s3-content` - Private content bucket
4. `route53-acm` - DNS and SSL certificates
5. `cloudfront` - CDN distribution

#### Error Handling

- **Retry Logic**: Automatic retries for transient failures
- **Validation**: Pre-deployment validation and security scanning
- **Rollback**: Manual rollback via destroy workflow
- **Notifications**: Clear success/failure notifications

#### Usage Examples

##### Automatic Deployment
```bash
# Push to develop branch triggers automatic deployment
git push origin develop
```

##### Manual Component Deployment
1. Go to Actions tab in GitHub
2. Select "Deploy Development Environment"
3. Click "Run workflow"
4. Select component and action
5. Click "Run workflow"

##### Pull Request Validation
```bash
# Create PR to develop branch for validation
git checkout -b feature/my-feature
git push origin feature/my-feature
# Create PR to develop branch
```

## Production Deployment Features

### Manual Approval Gates

Production deployments require manual approval to ensure safety:

1. **Automatic Plan Generation**: Plans are generated automatically on push to main
2. **Approval Required**: Human approval required before applying changes
3. **Emergency Override**: Skip approval option for critical deployments
4. **Plan Artifacts**: Detailed plan artifacts saved for review

### State Backup and Rollback

Production deployments include comprehensive backup and rollback capabilities:

#### Automatic State Backup
- Creates timestamped backup before any changes
- Stores backup in S3 with retention policies
- Enables quick recovery from failed deployments

#### Automatic Rollback
- Triggers on deployment failures
- Restores previous state from backup
- Refreshes infrastructure to ensure consistency
- Provides detailed rollback notifications

### Enhanced Notifications

Production workflow includes comprehensive notification system:

#### Slack Integration
Configure `SLACK_WEBHOOK_URL` secret for notifications:
- Deployment start/completion
- Approval requests
- Failure alerts
- Rollback notifications

#### Notification Types
- 📋 Plan ready for review
- 🚀 Deployment started
- ✅ Deployment successful
- ❌ Deployment failed
- 🔄 Rollback started/completed
- 🗑️ Destroy operations

### Production Safety Features

#### Enhanced Security Scanning
- Stricter Checkov policies for production
- Security scan results uploaded to GitHub Security
- Deployment blocked on critical security issues

#### Verification Steps
- Post-deployment verification of all components
- Output validation for critical resources
- Health checks for deployed services

#### Timeout Protection
- 30-minute timeout for apply operations
- Prevents hanging deployments
- Automatic failure detection

### Production Workflow Usage

#### Standard Production Deployment
```bash
# Push to main branch triggers plan generation
git push origin main

# Manual approval required in GitHub Actions UI
# 1. Go to Actions tab
# 2. Find the workflow run
# 3. Review plan artifacts
# 4. Approve deployment in "production-approval" environment
```

#### Emergency Production Deployment
```bash
# Use manual dispatch with skip approval
# 1. Go to Actions tab
# 2. Select "Deploy Production Environment"
# 3. Click "Run workflow"
# 4. Set action to "apply"
# 5. Check "Skip manual approval"
# 6. Click "Run workflow"
```

#### Production Component Deployment
```bash
# Deploy specific component to production
# 1. Go to Actions tab
# 2. Select "Deploy Production Environment"
# 3. Click "Run workflow"
# 4. Select specific component (e.g., "cloudfront")
# 5. Set action to "apply"
# 6. Click "Run workflow"
# 7. Approve when prompted
```

### Rollback Procedures

#### Automatic Rollback
- Triggers automatically on deployment failures
- Restores state from pre-deployment backup
- No manual intervention required

#### Manual Rollback
If automatic rollback fails:

1. **Check Backup Timestamp**:
   ```bash
   # Find backup timestamp in workflow logs
   # Look for "Backup timestamp: YYYYMMDD-HHMMSS"
   ```

2. **Manual State Restoration**:
   ```bash
   # Connect to AWS and restore manually
   aws s3 cp s3://your-state-bucket/backups/TIMESTAMP/ s3://your-state-bucket/ --recursive
   ```

3. **Refresh Infrastructure**:
   ```bash
   cd environments/prod
   terragrunt run-all refresh
   ```

### Production Monitoring

#### Key Metrics to Monitor
- Deployment success/failure rates
- Approval response times
- Rollback frequency
- Security scan results

#### Post-Deployment Verification
The workflow automatically verifies:
- Resource creation success
- Output availability
- Basic connectivity tests
- Configuration compliance

## AWS Permissions

The GitHub Actions workflow requires the following AWS permissions:

### IAM Policy for GitHub Actions

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*",
                "cloudfront:*",
                "cognito-idp:*",
                "cognito-identity:*",
                "route53:*",
                "acm:*",
                "iam:GetRole",
                "iam:CreateRole",
                "iam:DeleteRole",
                "iam:AttachRolePolicy",
                "iam:DetachRolePolicy",
                "iam:PutRolePolicy",
                "iam:DeleteRolePolicy",
                "iam:GetRolePolicy",
                "iam:ListRolePolicies",
                "iam:ListAttachedRolePolicies",
                "iam:PassRole"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:DeleteItem"
            ],
            "Resource": "arn:aws:dynamodb:*:*:table/terraform-state-lock-*"
        }
    ]
}
```

### Creating AWS User for GitHub Actions

1. Create IAM user for GitHub Actions:
```bash
aws iam create-user --user-name github-actions-terraform
```

2. Attach the policy:
```bash
aws iam attach-user-policy --user-name github-actions-terraform --policy-arn arn:aws:iam::ACCOUNT:policy/GitHubActionsTerraformPolicy
```

3. Create access keys:
```bash
aws iam create-access-key --user-name github-actions-terraform
```

4. Add the access key and secret to GitHub repository secrets.

## Security Considerations

### Checkov Security Scanning

The workflow includes automated security scanning using Checkov:

- Scans all Terraform configurations
- Uploads results to GitHub Security tab
- Fails workflow on critical security issues
- Allows skipping specific checks for development environment

### Environment Protection

- Uses GitHub environments for deployment approval
- Separate environment for destroy operations
- Requires repository admin approval for sensitive operations

### Credential Management

- AWS credentials stored as GitHub secrets
- No hardcoded credentials in workflow files
- Temporary credentials used during workflow execution

## Troubleshooting

### Common Issues

1. **AWS Credentials Error**
   - Verify secrets are correctly configured
   - Check IAM permissions for the user
   - Ensure AWS region is correct

2. **Terragrunt Initialization Failure**
   - Check S3 state bucket exists and is accessible
   - Verify DynamoDB lock table is available
   - Check network connectivity to AWS

3. **Security Scan Failures**
   - Review Checkov results in Security tab
   - Update configurations to fix security issues
   - Add skip checks for acceptable risks

4. **Component Dependencies**
   - Ensure components are deployed in correct order
   - Check for circular dependencies
   - Verify module outputs are available

### Debug Mode

Enable debug logging by setting repository variable:
- `ACTIONS_STEP_DEBUG`: `true`

### Manual Intervention

#### Development Issues
If automatic deployment fails:

1. Check workflow logs for specific errors
2. Run Terragrunt commands locally to debug
3. Use manual dispatch to deploy specific components
4. Contact infrastructure team for complex issues

#### Production Issues

**Deployment Failures:**
1. Check if automatic rollback completed successfully
2. Verify infrastructure state using AWS console
3. Review backup timestamp and restoration logs
4. If rollback failed, follow manual rollback procedures

**Approval Process Issues:**
1. Ensure approvers have correct GitHub permissions
2. Check environment protection rules configuration
3. Use emergency skip approval for critical fixes
4. Review plan artifacts before approval

**State Corruption:**
1. Identify backup timestamp from workflow logs
2. Manually restore state from S3 backup
3. Run `terragrunt refresh` to sync state
4. Verify resource consistency in AWS console

**Notification Failures:**
1. Verify Slack webhook URL is correctly configured
2. Check webhook permissions and channel access
3. Review notification payload in workflow logs
4. Test webhook manually if needed

## Monitoring

### Workflow Metrics

Monitor these metrics for workflow health:

- Success/failure rates
- Execution duration
- Component deployment times
- Security scan results

### AWS Resource Monitoring

After deployment, monitor:

- CloudFront distribution status
- S3 bucket access patterns
- Cognito user pool metrics
- Route 53 DNS resolution

## Next Steps

1. Configure GitHub repository secrets
2. Set up environment protection rules
3. Test workflow with a feature branch
4. Monitor first production deployment
5. Set up alerting for workflow failures