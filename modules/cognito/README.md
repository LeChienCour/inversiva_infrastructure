# Cognito Authentication Module

This Terraform module creates AWS Cognito resources for user authentication and authorization, including User Pool, User Pool Client, and Identity Pool with associated IAM roles.

## Features

- **User Pool**: Manages user registration, authentication, and user attributes
- **User Pool Client**: Configures OAuth2/OIDC settings for frontend integration
- **Identity Pool**: Provides AWS resource access for authenticated users
- **IAM Roles**: Separate roles for authenticated and unauthenticated users
- **Environment-based Configuration**: Different settings for dev and prod environments
- **Security**: Advanced security features, MFA, and password policies

## Usage

### Basic Usage

```hcl
module "cognito" {
  source = "./modules/cognito"

  project_name = "my-nextjs-app"
  environment  = "dev"

  callback_urls = [
    "https://dev.example.com/auth/callback",
    "http://localhost:3000/auth/callback"
  ]
  
  logout_urls = [
    "https://dev.example.com/auth/logout",
    "http://localhost:3000/auth/logout"
  ]

  tags = {
    Environment = "dev"
    Project     = "my-nextjs-app"
  }
}
```

### Production Configuration

```hcl
module "cognito" {
  source = "./modules/cognito"

  project_name = "my-nextjs-app"
  environment  = "prod"

  # Enhanced password policy for production
  password_policy = {
    minimum_length                   = 12
    require_lowercase               = true
    require_numbers                 = true
    require_symbols                 = true
    require_uppercase               = true
    temporary_password_validity_days = 3
  }

  # Enable MFA for production
  mfa_configuration = "ON"

  callback_urls = ["https://example.com/auth/callback"]
  logout_urls   = ["https://example.com/auth/logout"]

  # Link to content bucket for IAM policies
  content_bucket_arn = "arn:aws:s3:::my-content-bucket"

  tags = {
    Environment = "prod"
    Project     = "my-nextjs-app"
  }
}
```

## Environment-Specific Behavior

### Development Environment
- Advanced security mode: OFF
- Deletion protection: INACTIVE
- Relaxed password policies
- Optional MFA

### Production Environment
- Advanced security mode: ENFORCED
- Deletion protection: ACTIVE
- Strict password policies
- MFA can be enforced

## Integration with Next.js

The module outputs a `cognito_config` object that contains all necessary configuration for frontend integration:

```javascript
// Example Next.js configuration
const cognitoConfig = {
  userPoolId: 'us-east-1_XXXXXXXXX',
  userPoolClientId: 'XXXXXXXXXXXXXXXXXXXXXXXXXX',
  identityPoolId: 'us-east-1:XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX',
  region: 'us-east-1',
  oauth: {
    domain: 'my-app-dev.auth.us-east-1.amazoncognito.com',
    scope: ['email', 'openid', 'profile'],
    redirectUri: 'https://dev.example.com/auth/callback',
    responseType: 'code'
  }
};
```

## IAM Permissions

The module creates IAM roles with the following permissions:

### Authenticated Users
- Access to S3 objects tagged with their user ID
- Ability to assume role with web identity

### Unauthenticated Users (if enabled)
- Limited access as defined by the unauthenticated role policy

## Security Considerations

1. **Password Policies**: Configurable based on environment requirements
2. **MFA**: Can be enforced for production environments
3. **Advanced Security**: AWS Cognito advanced security features enabled in production
4. **Token Validity**: Configurable token expiration times
5. **IAM Policies**: Least privilege access to AWS resources

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |

## Resources

| Name | Type |
|------|------|
| aws_cognito_user_pool.main | resource |
| aws_cognito_user_pool_client.main | resource |
| aws_cognito_identity_pool.main | resource |
| aws_iam_role.authenticated | resource |
| aws_iam_role.unauthenticated | resource |
| aws_iam_role_policy.authenticated | resource |
| aws_cognito_identity_pool_roles_attachment.main | resource |
| aws_region.current | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Name of the project | `string` | n/a | yes |
| environment | Environment name (dev/prod) | `string` | n/a | yes |
| password_policy | Password policy configuration | `object` | See variables.tf | no |
| mfa_configuration | MFA configuration | `string` | `"OPTIONAL"` | no |
| explicit_auth_flows | Authentication flows | `list(string)` | See variables.tf | no |
| allowed_oauth_flows | OAuth flows | `list(string)` | `["code", "implicit"]` | no |
| allowed_oauth_scopes | OAuth scopes | `list(string)` | `["email", "openid", "profile"]` | no |
| callback_urls | OAuth callback URLs | `list(string)` | `["http://localhost:3000/auth/callback"]` | no |
| logout_urls | OAuth logout URLs | `list(string)` | `["http://localhost:3000/auth/logout"]` | no |
| token_validity | Token validity periods | `object` | See variables.tf | no |
| allow_unauthenticated_identities | Allow unauthenticated access | `bool` | `false` | no |
| content_bucket_arn | S3 content bucket ARN | `string` | `""` | no |
| tags | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| user_pool_id | Cognito User Pool ID |
| user_pool_arn | Cognito User Pool ARN |
| user_pool_endpoint | Cognito User Pool endpoint |
| user_pool_client_id | Cognito User Pool Client ID |
| identity_pool_id | Cognito Identity Pool ID |
| authenticated_role_arn | IAM role ARN for authenticated users |
| cognito_config | Complete configuration object for frontend |

## Examples

See the `examples/` directory for complete usage examples:

- `basic-setup/`: Minimal configuration for development
- `production-setup/`: Production-ready configuration with enhanced security
- `nextjs-integration/`: Example Next.js integration code

## Testing

The module includes validation for:
- Environment values (dev/prod only)
- MFA configuration options
- Password policy requirements

## Cost Optimization

- Development environments use minimal security features
- Production environments balance security and cost
- Token validity periods optimized for user experience and security
- IAM policies follow least privilege principle

## Troubleshooting

### Common Issues

1. **OAuth Configuration**: Ensure callback URLs match your application's redirect URIs
2. **IAM Permissions**: Verify that the content bucket ARN is correctly specified
3. **Token Expiration**: Adjust token validity periods based on your application needs
4. **MFA Issues**: Check MFA configuration matches your security requirements

### Debug Information

Enable Terraform debug logging to troubleshoot issues:
```bash
export TF_LOG=DEBUG
terraform plan
```