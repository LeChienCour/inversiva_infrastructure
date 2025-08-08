# S3 Content Storage Module

This Terraform module creates a private S3 bucket designed for storing user-specific content with Cognito-based access control. Users can only access their own content through direct S3 operations or presigned URLs, making it perfect for Next.js applications with user authentication.

## Features

- **Private S3 Bucket**: Completely private bucket with all public access blocked
- **Cognito Integration**: Direct integration with AWS Cognito for user-specific folder access
- **User Isolation**: Each user can only access `users/{cognito-user-id}/` folder
- **Server-Side Encryption**: AES-256 encryption enabled by default
- **Lifecycle Policies**: Configurable transitions to IA and Glacier storage classes
- **Versioning Support**: Optional S3 bucket versioning
- **CORS Configuration**: Configured for web application access (GET, HEAD, PUT, POST)
- **Admin Access**: Separate IAM policy for admin operations
- **Cost Optimization**: Environment-specific lifecycle policies for cost control

## Cognito-Based Access Control

This module is designed for Next.js applications where:
- **Users authenticate via AWS Cognito**
- **Each user can only access their own folder**: `users/{cognito-user-id}/`
- **Access is controlled by IAM policies using Cognito identity**
- **No backend API needed** for basic file operations

### Folder Structure

The module automatically enforces this structure through IAM policies:

```
s3://your-content-bucket/
└── users/
    ├── {cognito-user-id-1}/        # User 1's private folder
    │   ├── video1.mp4
    │   ├── document.pdf
    │   └── image.jpg
    ├── {cognito-user-id-2}/        # User 2's private folder
    │   └── their-content.mp4
    └── {cognito-user-id-3}/        # User 3's private folder
        └── more-content.pdf
```

### Access Patterns

1. **Direct Upload**: Users upload directly from browser using Cognito credentials
2. **Direct Download**: Users download directly using Cognito credentials or presigned URLs
3. **Automatic Isolation**: IAM policies ensure users can only access their own folder
4. **Admin Access**: Separate admin policy for full bucket access

## Usage

### Basic Usage with Cognito Integration

```hcl
module "s3_content" {
  source = "./modules/s3-content"
  
  bucket_name_prefix    = "myapp"
  environment          = "prod"
  cognito_user_pool_arn = module.cognito.user_pool_arn
  
  # CORS configuration for your Next.js app
  cors_allowed_origins = [
    "https://myapp.example.com",
    "http://localhost:3000"  # For development
  ]
  
  tags = {
    Project = "MyApplication"
    Owner   = "DevOps Team"
  }
}
```

### Advanced Usage with Custom Lifecycle Policies

```hcl
module "s3_content" {
  source = "./modules/s3-content"
  
  bucket_name_prefix    = "myapp"
  environment          = "dev"
  cognito_user_pool_arn = module.cognito.user_pool_arn
  
  # Cost optimization for development
  lifecycle_transition_ia_days      = 7   # Transition to IA after 7 days
  lifecycle_transition_glacier_days = 30  # Transition to Glacier after 30 days
  
  # Shorter retention for dev environment
  lifecycle_noncurrent_version_expiration_days = 30
  
  # Custom CORS configuration
  cors_allowed_origins = [
    "https://dev.myapp.example.com",
    "http://localhost:3000"
  ]
  
  # Shorter presigned URL expiration for development
  presigned_url_expiration_seconds = 300  # 5 minutes
  
  tags = {
    Project     = "MyApplication"
    Environment = "Development"
    Owner       = "DevOps Team"
  }
}
```

### Production Configuration Example

```hcl
module "s3_content_prod" {
  source = "./modules/s3-content"
  
  bucket_name_prefix = "myapp"
  environment        = "prod"
  
  # Production-optimized lifecycle policies
  lifecycle_transition_ia_days      = 30  # Keep in Standard for 30 days
  lifecycle_transition_glacier_days = 90  # Move to Glacier after 90 days
  
  # Longer retention for production
  lifecycle_noncurrent_version_expiration_days = 365
  
  # Shorter presigned URL expiration for security
  presigned_url_expiration_seconds = 300  # 5 minutes
  
  # Restrictive CORS for production
  cors_allowed_origins = [
    "https://myapp.example.com"
  ]
  
  tags = {
    Project     = "MyApplication"
    Environment = "Production"
    Owner       = "DevOps Team"
    Backup      = "Required"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |
| random | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |
| random | >= 3.0 |

## Resources

| Name | Type |
|------|------|
| [aws_s3_bucket.content_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_public_access_block.content_bucket_pab](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_versioning.content_bucket_versioning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.content_bucket_encryption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.content_bucket_lifecycle](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_cors_configuration.content_bucket_cors](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_cors_configuration) | resource |
| [aws_iam_policy.presigned_url_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.presigned_url_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.presigned_url_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [random_id.bucket_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| bucket_name_prefix | Prefix for the S3 bucket name. Will be combined with environment and random suffix | `string` | n/a | yes |
| environment | Environment name (dev, staging, prod) | `string` | n/a | yes |
| enable_versioning | Enable S3 bucket versioning | `bool` | `true` | no |
| enable_lifecycle_policy | Enable lifecycle policy for cost optimization | `bool` | `true` | no |
| lifecycle_transition_ia_days | Number of days after which objects transition to Standard-IA storage class (0 to disable) | `number` | `30` | no |
| lifecycle_transition_glacier_days | Number of days after which objects transition to Glacier storage class (0 to disable) | `number` | `90` | no |
| lifecycle_noncurrent_version_expiration_days | Number of days after which noncurrent object versions are deleted | `number` | `90` | no |
| cors_allowed_origins | List of allowed origins for CORS configuration | `list(string)` | `["*"]` | no |
| presigned_url_expiration_seconds | Default expiration time for presigned URLs in seconds | `number` | `900` | no |
| enable_user_specific_structure | Enable user-specific folder structure and policies | `bool` | `true` | no |
| user_content_prefix | Prefix for user-specific content (e.g., 'users' creates users/{user-id}/ structure) | `string` | `"users"` | no |
| admin_upload_prefix | Prefix for admin upload area (separate from user content) | `string` | `"admin-uploads"` | no |
| content_types | List of content types/folders to organize under each user (e.g., videos, documents, images) | `list(string)` | `["videos", "documents", "images"]` | no |
| enable_access_logging | Enable S3 access logging for content downloads tracking | `bool` | `false` | no |
| access_log_bucket | S3 bucket name for access logs (required if enable_access_logging is true) | `string` | `""` | no |
| access_log_prefix | Prefix for access log objects | `string` | `"content-access-logs/"` | no |
| create_presigned_url_policy | Whether to create an IAM policy for presigned URL generation | `bool` | `true` | no |
| create_presigned_url_role | Whether to create an IAM role for presigned URL generation | `bool` | `false` | no |
| presigned_url_role_trusted_services | List of AWS services that can assume the presigned URL role | `list(string)` | `["lambda.amazonaws.com", "ec2.amazonaws.com"]` | no |
| tags | Additional tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| bucket_id | The ID of the S3 content bucket |
| bucket_arn | The ARN of the S3 content bucket |
| bucket_name | The name of the S3 content bucket |
| bucket_domain_name | The bucket domain name for the S3 content bucket |
| bucket_regional_domain_name | The bucket regional domain name for the S3 content bucket |
| bucket_region | The AWS region where the S3 content bucket is located |
| presigned_url_expiration_seconds | Default expiration time for presigned URLs in seconds |
| presigned_url_policy_json | IAM policy JSON for presigned URL generation permissions |
| presigned_url_example_command | Example AWS CLI command for generating presigned URLs |
| user_content_prefix | Prefix used for user-specific content organization |
| admin_upload_prefix | Prefix used for admin uploads |
| content_types | List of content types configured for user organization |
| user_content_structure_example | Example of user content structure |
| admin_policy_arn | ARN of the IAM policy for admin operations |
| admin_policy_name | Name of the IAM policy for admin operations |
| presigned_url_policy_arn | ARN of the IAM policy for user-specific presigned URL generation |
| presigned_url_policy_name | Name of the IAM policy for user-specific presigned URL generation |
| backend_service_policy_arn | ARN of the IAM policy for backend services |
| backend_service_policy_name | Name of the IAM policy for backend services |
| backend_service_role_arn | ARN of the IAM role for backend services |
| backend_service_role_name | Name of the IAM role for backend services |
| admin_role_arn | ARN of the IAM role for admin operations |
| admin_role_name | Name of the IAM role for admin operations |

## Security Features

### Private Access
- All public access is blocked via `aws_s3_bucket_public_access_block`
- No public read or write permissions
- Content accessible only via presigned URLs or authenticated AWS API calls

### Encryption
- Server-side encryption with AES-256 enabled by default
- Bucket key enabled for cost optimization
- All objects encrypted at rest

### IAM Integration
- Optional IAM policy for presigned URL generation with minimal required permissions
- Optional IAM role for service-to-service access
- Follows principle of least privilege

### CORS Configuration
- Configurable CORS rules for web application integration
- Supports GET and HEAD methods for content retrieval
- Customizable allowed origins

## Cost Optimization

### Lifecycle Policies
- Automatic transition to Standard-IA storage class after configurable days
- Optional transition to Glacier for long-term archival
- Automatic cleanup of incomplete multipart uploads
- Configurable retention for noncurrent object versions

### Environment-Specific Optimization
- **Development**: Aggressive lifecycle policies for cost savings
- **Production**: Balanced approach between performance and cost
- **Staging**: Moderate lifecycle policies for testing scenarios

### Storage Class Recommendations
- **Standard**: For frequently accessed content (< 30 days)
- **Standard-IA**: For infrequently accessed content (30-90 days)
- **Glacier**: For archival content (> 90 days)

## Presigned URL Generation

### Using AWS CLI
```bash
# Generate a presigned URL for GET operation (15 minutes expiration)
aws s3 presign s3://your-bucket-name/path/to/object --expires-in 900

# Generate a presigned URL for PUT operation
aws s3 presign s3://your-bucket-name/path/to/object --expires-in 900 --method PUT
```

### Using AWS SDK (Node.js Example)
```javascript
const AWS = require('aws-sdk');
const s3 = new AWS.S3();

const params = {
    Bucket: 'your-bucket-name',
    Key: 'path/to/object',
    Expires: 900 // 15 minutes
};

// Generate presigned URL for GET
const url = s3.getSignedUrl('getObject', params);

// Generate presigned URL for PUT
const uploadUrl = s3.getSignedUrl('putObject', params);
```

### Using AWS SDK (Python Example)
```python
import boto3
from botocore.exceptions import ClientError

s3_client = boto3.client('s3')

try:
    # Generate presigned URL for GET
    response = s3_client.generate_presigned_url(
        'get_object',
        Params={'Bucket': 'your-bucket-name', 'Key': 'path/to/object'},
        ExpiresIn=900
    )
    
    # Generate presigned URL for PUT
    upload_response = s3_client.generate_presigned_url(
        'put_object',
        Params={'Bucket': 'your-bucket-name', 'Key': 'path/to/object'},
        ExpiresIn=900
    )
except ClientError as e:
    print(f"Error generating presigned URL: {e}")
```

## Best Practices

### Security
1. **Short Expiration Times**: Use short expiration times for presigned URLs (5-15 minutes)
2. **Restrictive CORS**: Configure CORS to allow only necessary origins
3. **IAM Permissions**: Use the provided IAM policy with minimal required permissions
4. **Monitoring**: Enable CloudTrail logging for S3 API calls

### Cost Optimization
1. **Lifecycle Policies**: Configure appropriate lifecycle transitions based on access patterns
2. **Versioning**: Enable versioning only when necessary
3. **Monitoring**: Use S3 Storage Class Analysis to optimize storage classes
4. **Cleanup**: Regularly review and clean up unused objects

### Performance
1. **Regional Deployment**: Deploy buckets in the same region as your application
2. **Request Patterns**: Avoid sequential key names to prevent hot partitioning
3. **Multipart Uploads**: Use multipart uploads for large files (>100MB)
4. **Transfer Acceleration**: Consider S3 Transfer Acceleration for global applications

## Troubleshooting

### Common Issues

#### Access Denied Errors
- Verify IAM permissions include the required S3 actions
- Check that the bucket policy doesn't conflict with IAM policies
- Ensure presigned URLs haven't expired

#### CORS Errors
- Verify the requesting origin is included in `cors_allowed_origins`
- Check that the HTTP method is allowed (GET, HEAD)
- Ensure proper headers are included in the CORS configuration

#### Lifecycle Policy Issues
- Verify transition days are in ascending order (IA < Glacier)
- Check that minimum storage duration requirements are met
- Ensure objects meet minimum size requirements for IA/Glacier

### Debugging Commands

```bash
# Check bucket policy
aws s3api get-bucket-policy --bucket your-bucket-name

# List bucket lifecycle configuration
aws s3api get-bucket-lifecycle-configuration --bucket your-bucket-name

# Check bucket CORS configuration
aws s3api get-bucket-cors --bucket your-bucket-name

# Test presigned URL generation
aws s3 presign s3://your-bucket-name/test-object --expires-in 300
```

## Migration Guide

### From Existing S3 Buckets
1. Export existing bucket configuration
2. Update Terraform configuration to match existing settings
3. Import existing bucket using `terraform import`
4. Apply lifecycle and security configurations gradually

### Version Upgrades
- Review CHANGELOG.md for breaking changes
- Test in development environment first
- Plan and apply changes during maintenance windows

## Contributing

When contributing to this module:
1. Follow Terraform best practices
2. Update documentation for any new variables or outputs
3. Add appropriate validation rules for new variables
4. Test with multiple environments (dev, staging, prod)
5. Update examples in README.md

## License

This module is licensed under the MIT License. See LICENSE file for details.