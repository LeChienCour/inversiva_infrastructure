# Bootstrap Infrastructure

This directory contains the Terraform configuration to bootstrap the infrastructure required for remote state management.

## Overview

Before using Terragrunt to deploy the main infrastructure, you need to create:
- An S3 bucket to store Terraform state files
- A DynamoDB table for state locking

## Prerequisites

1. **AWS CLI configured** with appropriate credentials
2. **Terraform installed** (version >= 1.0)
3. **Appropriate AWS permissions** to create S3 buckets and DynamoDB tables

### Required AWS Permissions

Your AWS credentials need the following permissions:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:CreateBucket",
                "s3:PutBucketVersioning",
                "s3:PutBucketEncryption",
                "s3:PutBucketPublicAccessBlock",
                "s3:PutLifecycleConfiguration",
                "s3:GetBucketLocation",
                "dynamodb:CreateTable",
                "dynamodb:DescribeTable",
                "sts:GetCallerIdentity"
            ],
            "Resource": "*"
        }
    ]
}
```

## Usage

### Option 1: Using the Bootstrap Script (Recommended)

**Linux/macOS:**
```bash
cd bootstrap
chmod +x bootstrap.sh
./bootstrap.sh
```

**Windows (PowerShell):**
```powershell
cd bootstrap
.\bootstrap.ps1
```

### Option 2: Manual Terraform Commands

```bash
cd bootstrap
terraform init
terraform plan
terraform apply
```

## What Gets Created

1. **S3 Bucket**: `terraform-nextjs-infrastructure-tfstate-{account-id}-{region}`
   - Versioning enabled for state recovery
   - Server-side encryption (AES-256)
   - Public access blocked
   - Lifecycle policies for cost optimization

2. **DynamoDB Table**: `terraform-nextjs-infrastructure-tfstate-lock`
   - Pay-per-request billing mode
   - Used for state locking to prevent concurrent modifications

## Cost Considerations

- **S3 Bucket**: Minimal cost for state files (typically < $1/month)
- **DynamoDB Table**: Pay-per-request pricing (typically < $1/month for small teams)
- **Lifecycle Policies**: Automatically move old state versions to cheaper storage

## Security Features

- S3 bucket encryption enabled
- Public access completely blocked
- State locking prevents concurrent modifications
- Versioning enables recovery from corruption

## Troubleshooting

### Common Issues

1. **AWS credentials not configured**
   ```bash
   aws configure
   ```

2. **Insufficient permissions**
   - Ensure your AWS user/role has the required permissions listed above

3. **Bucket name conflicts**
   - The bucket name includes your account ID to ensure uniqueness
   - If conflicts occur, check for existing resources

4. **Region mismatch**
   - Ensure your AWS CLI default region matches your intended deployment region

### Cleanup

To destroy the bootstrap infrastructure (⚠️ **This will delete your state files**):

```bash
cd bootstrap
terraform destroy
```

**Warning**: Only do this if you're sure you want to delete all Terraform state files and start over.

## Next Steps

After successful bootstrap:

1. Navigate to an environment directory (e.g., `environments/dev/`)
2. Run `terragrunt plan` to see what will be created
3. Run `terragrunt apply` to deploy the infrastructure

The bootstrap infrastructure will automatically be used by Terragrunt for state management.