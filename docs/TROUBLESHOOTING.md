# Troubleshooting Guide

This comprehensive troubleshooting guide covers common issues, solutions, and debugging procedures for the Terraform Next.js infrastructure project.

## Quick Reference

### Emergency Commands
```bash
# Check infrastructure status
cd environments/dev && terragrunt run-all plan

# Force unlock state (use with caution)
terragrunt force-unlock <LOCK_ID>

# Refresh state to sync with AWS
terragrunt refresh

# Import existing resource
terragrunt import <resource_type>.<resource_name> <resource_id>
```

### Log Locations
- **Terragrunt Cache**: `.terragrunt-cache/`
- **GitHub Actions**: Actions tab → Workflow run → Job logs
- **AWS CloudTrail**: AWS Console → CloudTrail → Event history
- **Local Logs**: `~/.terragrunt/terragrunt.log` (if enabled)

## Common Issues and Solutions

### 1. State Management Issues

#### State Lock Errors
```
Error: Error acquiring the state lock
```

**Causes:**
- Previous Terragrunt process was interrupted
- Multiple users running Terragrunt simultaneously
- DynamoDB table permissions issues

**Solutions:**
```bash
# Check who has the lock
aws dynamodb scan --table-name terraform-state-lock --region us-east-1

# Force unlock (use with extreme caution)
terragrunt force-unlock <LOCK_ID>

# Verify DynamoDB permissions
aws dynamodb describe-table --table-name terraform-state-lock --region us-east-1
```

#### State File Corruption
```
Error: Failed to load state
```

**Solutions:**
```bash
# List state backups
aws s3 ls s3://your-state-bucket/environments/dev/cognito/ --recursive

# Restore from backup
aws s3 cp s3://your-state-bucket/environments/dev/cognito/terraform.tfstate.backup \
  s3://your-state-bucket/environments/dev/cognito/terraform.tfstate

# Refresh state
terragrunt refresh
```

#### State Drift Detection
```bash
# Detect drift
terragrunt plan -detailed-exitcode

# Import drifted resources
terragrunt import aws_s3_bucket.website your-bucket-name

# Refresh state to match reality
terragrunt refresh
```

### 2. AWS Authentication Issues

#### Invalid Credentials
```
Error: Unable to locate credentials
```

**Solutions:**
```bash
# Verify AWS CLI configuration
aws sts get-caller-identity

# Check environment variables
echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY
echo $AWS_REGION

# Reconfigure AWS CLI
aws configure

# Use AWS SSO (if applicable)
aws sso login --profile your-profile
```

#### Permission Denied Errors
```
Error: AccessDenied: User is not authorized
```

**Solutions:**
```bash
# Check current user permissions
aws iam get-user
aws iam list-attached-user-policies --user-name your-username

# Test specific permissions
aws s3 ls  # Test S3 access
aws cognito-idp list-user-pools --max-results 10  # Test Cognito access

# Verify IAM policy attachments
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:user/your-user \
  --action-names s3:CreateBucket \
  --resource-arns arn:aws:s3:::*
```

### 3. Module and Configuration Issues

#### Module Not Found
```
Error: Module not found
```

**Solutions:**
```bash
# Verify module path in terragrunt.hcl
cat terragrunt.hcl | grep source

# Check module directory structure
ls -la ../../../modules/cognito/

# Validate module syntax
cd ../../../modules/cognito && terraform validate

# Clear Terragrunt cache
rm -rf .terragrunt-cache
```

#### Variable Validation Errors
```
Error: Invalid value for variable
```

**Solutions:**
```bash
# Check variable definitions
cat variables.tf | grep -A 5 "variable \"problematic_var\""

# Verify input values
cat terragrunt.hcl | grep -A 10 inputs

# Validate variable types
terraform console
> var.problematic_var
```

#### Dependency Issues
```
Error: Resource not found
```

**Solutions:**
```bash
# Check dependency order
terragrunt graph-dependencies

# Deploy dependencies first
cd ../s3-website && terragrunt apply
cd ../cognito && terragrunt apply

# Use run-all for proper ordering
cd .. && terragrunt run-all apply
```

### 4. Resource-Specific Issues

#### S3 Bucket Issues

**Bucket Already Exists**
```
Error: BucketAlreadyExists
```
```bash
# Check if bucket exists in your account
aws s3 ls | grep your-bucket-name

# Import existing bucket
terragrunt import aws_s3_bucket.website your-bucket-name

# Use different bucket name
# Edit terragrunt.hcl and change bucket_prefix
```

**Public Access Block Conflicts**
```
Error: InvalidBucketState
```
```bash
# Check current public access settings
aws s3api get-public-access-block --bucket your-bucket-name

# Remove conflicting settings
aws s3api delete-public-access-block --bucket your-bucket-name

# Re-apply Terraform configuration
terragrunt apply
```

#### CloudFront Issues

**Certificate Validation Timeout**
```
Error: CertificateNotFound or ValidationTimeout
```
```bash
# Check certificate status
aws acm list-certificates --region us-east-1

# Verify DNS validation records
aws route53 list-resource-record-sets --hosted-zone-id Z123456789

# Check domain ownership
dig placeholder.mx

# Manual certificate validation
aws acm describe-certificate --certificate-arn arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012
```

**Distribution Deployment Stuck**
```
Status: InProgress for > 30 minutes
```
```bash
# Check distribution status
aws cloudfront get-distribution --id E123456789ABCD

# Monitor deployment progress
aws cloudfront list-distributions --query 'DistributionList.Items[?Status==`InProgress`]'

# Cancel and retry if necessary (rare)
terragrunt destroy
terragrunt apply
```

#### Cognito Issues

**User Pool Client Configuration**
```
Error: InvalidParameterException
```
```bash
# Check current configuration
aws cognito-idp describe-user-pool-client \
  --user-pool-id us-east-1_123456789 \
  --client-id 1234567890abcdef

# Verify OAuth settings
aws cognito-idp describe-user-pool \
  --user-pool-id us-east-1_123456789 \
  --query 'UserPool.Policies'

# Test authentication flow
aws cognito-idp admin-initiate-auth \
  --user-pool-id us-east-1_123456789 \
  --client-id 1234567890abcdef \
  --auth-flow ADMIN_NO_SRP_AUTH
```

### 5. GitHub Actions Issues

#### Workflow Permission Errors
```
Error: The request was denied due to insufficient permissions
```

**Solutions:**
```bash
# Check GitHub secrets
# Go to Settings → Secrets and variables → Actions
# Verify AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY

# Test credentials locally
aws sts get-caller-identity

# Check IAM policy for GitHub Actions user
aws iam get-user-policy --user-name github-actions-user --policy-name TerraformPolicy
```

#### Workflow Timeout Issues
```
Error: The job running on runner has exceeded the maximum execution time
```

**Solutions:**
```yaml
# Increase timeout in workflow file
jobs:
  deploy:
    timeout-minutes: 60  # Increase from default 30

# Use parallel execution
terragrunt run-all apply --terragrunt-parallelism 5

# Deploy components separately
# Use manual dispatch with specific components
```

#### Artifact Upload Failures
```
Error: Unable to upload artifact
```

**Solutions:**
```yaml
# Reduce artifact size
- name: Upload artifacts
  uses: actions/upload-artifact@v3
  with:
    name: terraform-plans
    path: |
      **/*.tfplan
      !**/.terragrunt-cache/**
    retention-days: 7
```

### 6. Security Scanning Issues

#### Checkov Failures
```
Error: Security scan failed with critical issues
```

**Solutions:**
```bash
# Run scan locally
checkov --config-file .checkov.yml --directory .

# Check specific policy
checkov --check CKV_AWS_18 --directory modules/

# Add exception if justified
./scripts/manage-security-exceptions.sh add \
  --check-id CKV_AWS_18 \
  --justification "Development environment optimization"

# Skip specific checks temporarily
checkov --skip-check CKV_AWS_18,CKV_AWS_19 --directory .
```

#### Custom Policy Errors
```
Error: Custom policy failed to load
```

**Solutions:**
```bash
# Validate Python syntax
python -m py_compile .checkov/custom_policies/*.py

# Test custom policy
checkov --external-checks-dir .checkov/custom_policies/ \
  --check CKV2_AWS_COGNITO_PASSWORD \
  --directory modules/cognito/

# Debug policy logic
python3 -c "
import sys
sys.path.append('.checkov/custom_policies')
from cognito_security import *
print('Policy loaded successfully')
"
```

### 7. Performance Issues

#### Slow Terragrunt Operations
```bash
# Enable debug logging
export TERRAGRUNT_LOG_LEVEL=debug
terragrunt plan

# Use parallelism
terragrunt run-all apply --terragrunt-parallelism 10

# Clear cache
rm -rf .terragrunt-cache

# Use specific components
terragrunt apply --terragrunt-include-dir cognito
```

#### Large State Files
```bash
# Analyze state size
terragrunt show -json | jq '.values.root_module.resources | length'

# Split large states
# Consider separating into more granular components

# Compress state
aws s3 cp terraform.tfstate - | gzip | aws s3 cp - s3://bucket/compressed-state.tfstate.gz
```

## Debugging Procedures

### 1. Systematic Debugging Approach

```bash
# Step 1: Verify basic setup
aws sts get-caller-identity
terraform version
terragrunt --version

# Step 2: Check configuration
terraform validate
terragrunt validate

# Step 3: Plan with detailed output
terragrunt plan -detailed-exitcode -out=plan.tfplan

# Step 4: Analyze plan
terraform show plan.tfplan

# Step 5: Apply with logging
TF_LOG=DEBUG terragrunt apply plan.tfplan
```

### 2. State Debugging

```bash
# List state resources
terragrunt state list

# Show specific resource
terragrunt state show aws_s3_bucket.website

# Check for drift
terragrunt plan -refresh-only

# Export state for analysis
terragrunt state pull > current-state.json
```

### 3. Network Debugging

```bash
# Test DNS resolution
dig placeholder.mx
nslookup placeholder.mx

# Test SSL certificate
openssl s_client -connect placeholder.mx:443 -servername placeholder.mx

# Test CloudFront
curl -I https://placeholder.mx
curl -H "Host: placeholder.mx" https://d123456789abcd.cloudfront.net
```

### 4. Application Integration Debugging

```bash
# Test Cognito authentication
aws cognito-idp admin-create-user \
  --user-pool-id us-east-1_123456789 \
  --username testuser \
  --temporary-password TempPass123! \
  --message-action SUPPRESS

# Test S3 presigned URLs
aws s3 presign s3://your-content-bucket/test-file.txt --expires-in 3600

# Test CloudFront cache
curl -I https://placeholder.mx/test-file.js
# Check X-Cache header: Hit from cloudfront vs Miss from cloudfront
```

## Prevention Strategies

### 1. Pre-deployment Checks

```bash
#!/bin/bash
# pre-deploy-check.sh

echo "Running pre-deployment checks..."

# Check AWS credentials
aws sts get-caller-identity || exit 1

# Validate Terraform
terraform validate || exit 1

# Check for state locks
terragrunt plan -lock=false -detailed-exitcode

# Run security scan
checkov --config-file .checkov.yml --directory . || exit 1

echo "All checks passed!"
```

### 2. Monitoring Setup

```bash
# Set up CloudWatch alarms
aws cloudwatch put-metric-alarm \
  --alarm-name "High-S3-Costs" \
  --alarm-description "Alert when S3 costs exceed threshold" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold

# Monitor state file changes
aws s3api put-bucket-notification-configuration \
  --bucket your-state-bucket \
  --notification-configuration file://state-change-notification.json
```

### 3. Backup Procedures

```bash
#!/bin/bash
# backup-state.sh

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_BUCKET="your-backup-bucket"

# Backup all state files
aws s3 sync s3://your-state-bucket/ s3://$BACKUP_BUCKET/backups/$TIMESTAMP/

# Backup configuration
git archive --format=tar.gz --output=config-backup-$TIMESTAMP.tar.gz HEAD

echo "Backup completed: $TIMESTAMP"
```

## Getting Help

### Internal Resources
1. **Project Documentation**: Check README.md and docs/ directory
2. **Module Documentation**: Each module has its own README
3. **GitHub Issues**: Search existing issues for similar problems
4. **Git History**: Check recent changes that might have caused issues

### External Resources
1. **Terraform Documentation**: https://www.terraform.io/docs
2. **Terragrunt Documentation**: https://terragrunt.gruntwork.io/docs
3. **AWS Documentation**: https://docs.aws.amazon.com/
4. **Community Forums**: 
   - Terraform Community: https://discuss.hashicorp.com/c/terraform-core
   - AWS Forums: https://forums.aws.amazon.com/
   - Stack Overflow: Use tags `terraform`, `terragrunt`, `aws`

### Emergency Contacts
- **Infrastructure Team**: infrastructure@placeholder.mx
- **Security Team**: security@placeholder.mx
- **On-call Engineer**: oncall@placeholder.mx

### Escalation Procedure
1. **Level 1**: Check this troubleshooting guide
2. **Level 2**: Search documentation and community forums
3. **Level 3**: Create GitHub issue with detailed information
4. **Level 4**: Contact infrastructure team
5. **Level 5**: Emergency escalation for production issues

## Troubleshooting Checklist

Before asking for help, ensure you have:

- [ ] Checked this troubleshooting guide
- [ ] Verified AWS credentials and permissions
- [ ] Validated Terraform/Terragrunt configuration
- [ ] Checked for state locks or corruption
- [ ] Reviewed recent changes in Git history
- [ ] Attempted the suggested solutions
- [ ] Collected relevant logs and error messages
- [ ] Documented steps to reproduce the issue

## Contributing to This Guide

If you encounter a new issue or find a solution not covered here:

1. Document the problem and solution
2. Test the solution thoroughly
3. Submit a pull request with updates to this guide
4. Include relevant commands, error messages, and explanations

This helps the entire team and prevents others from encountering the same issues.