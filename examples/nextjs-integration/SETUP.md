# Next.js AWS Integration Setup Guide

This guide will help you set up and integrate your Next.js application with the AWS infrastructure deployed by this Terraform/Terragrunt configuration.

## Prerequisites

Before you begin, ensure you have:

1. **Deployed AWS Infrastructure**: The Terraform/Terragrunt infrastructure must be deployed first
2. **Node.js**: Version 18.0.0 or higher
3. **npm**: Version 8.0.0 or higher
4. **AWS CLI**: Configured with appropriate permissions (for deployment)

## Quick Start

### 1. Install Dependencies

```bash
cd examples/nextjs-integration
npm install
```

### 2. Configure Environment Variables

Copy the environment template and update with your values:

```bash
cp config/env.example .env.local
```

Edit `.env.local` with your actual values from the Terraform outputs:

```bash
# Get Terraform outputs
cd ../../environments/dev  # or prod
terragrunt run-all output
```

### 3. Update Environment Variables

Update `.env.local` with the output values:

```env
# AWS Configuration
NEXT_PUBLIC_AWS_REGION=us-east-1

# Cognito Configuration (from Terraform outputs)
NEXT_PUBLIC_COGNITO_USER_POOL_ID=us-east-1_XXXXXXXXX
NEXT_PUBLIC_COGNITO_USER_POOL_CLIENT_ID=XXXXXXXXXXXXXXXXXXXXXXXXXX
NEXT_PUBLIC_COGNITO_IDENTITY_POOL_ID=us-east-1:XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
NEXT_PUBLIC_COGNITO_DOMAIN=my-app-dev.auth.us-east-1.amazoncognito.com

# S3 Configuration (from Terraform outputs)
NEXT_PUBLIC_S3_WEBSITE_BUCKET=my-app-dev-website-abc123
NEXT_PUBLIC_S3_CONTENT_BUCKET=my-app-dev-content-abc123

# CloudFront Configuration (from Terraform outputs)
NEXT_PUBLIC_CLOUDFRONT_DISTRIBUTION_ID=E1234567890123
NEXT_PUBLIC_CLOUDFRONT_DOMAIN=d1234567890123.cloudfront.net
NEXT_PUBLIC_CUSTOM_DOMAIN=placeholder.mx

# Application Configuration
NEXT_PUBLIC_ENVIRONMENT=dev
NEXT_PUBLIC_APP_NAME=My Next.js App
```

### 4. Start Development Server

```bash
npm run dev
```

Your application will be available at `http://localhost:3000`.

## Project Structure

```
examples/nextjs-integration/
├── auth/                          # Authentication components and services
│   ├── auth-service.js           # Cognito authentication service
│   ├── auth-context.jsx          # React context for auth state
│   ├── auth-components.jsx       # Ready-to-use auth components
│   └── auth-middleware.js        # Next.js middleware for route protection
├── content/                       # Content management components
│   ├── content-service.js        # S3 presigned URL service
│   ├── content-components.jsx    # Content management components
│   └── content-utils.js          # Content utility functions
├── config/                        # Configuration files
│   ├── env.example               # Environment variables template
│   ├── next.config.js           # Next.js configuration
│   └── amplify-config.js        # AWS Amplify configuration
├── deployment/                    # Deployment scripts
│   ├── deploy-to-s3.js          # Node.js deployment script
│   ├── deploy-to-s3.sh          # Shell deployment script
│   └── deploy-to-s3.ps1         # PowerShell deployment script
├── pages/                         # Next.js pages
│   ├── api/                      # API routes
│   │   ├── aws-credentials.js    # AWS credentials endpoint
│   │   └── content/              # Content management APIs
│   ├── auth/                     # Authentication pages
│   │   ├── login.jsx            # Login page
│   │   ├── register.jsx         # Registration page
│   │   ├── verify.jsx           # Email verification page
│   │   └── profile.jsx          # User profile page
│   └── content/                  # Content pages
│       └── gallery.jsx          # Content gallery page
├── package.json                   # Dependencies and scripts
├── SETUP.md                      # This setup guide
└── README.md                     # Project documentation
```

## Key Features

### Authentication (Cognito Integration)

- **User Registration**: Sign up with email verification
- **User Login**: Secure authentication with Cognito
- **Password Management**: Change password, forgot password flows
- **Profile Management**: Update user attributes
- **Route Protection**: Middleware-based route protection
- **Session Management**: Automatic token refresh

### Content Management (S3 Presigned URLs)

- **File Upload**: Secure file uploads using presigned URLs
- **File Download**: Secure file downloads with temporary URLs
- **File Management**: List, view, and delete user content
- **Progress Tracking**: Real-time upload progress
- **File Validation**: Client-side file type and size validation

### Deployment

- **Static Export**: Optimized for S3 static hosting
- **CloudFront Integration**: CDN distribution with cache invalidation
- **Environment Support**: Separate dev/prod configurations
- **Automated Deployment**: Scripts for CI/CD integration

## Usage Examples

### Authentication

```jsx
import { useAuth } from '../auth/auth-context';
import { LoginForm } from '../auth/auth-components';

function MyPage() {
  const { user, isAuthenticated, signOut } = useAuth();

  if (!isAuthenticated) {
    return <LoginForm />;
  }

  return (
    <div>
      <h1>Welcome, {user.attributes.given_name}!</h1>
      <button onClick={signOut}>Sign Out</button>
    </div>
  );
}
```

### Content Management

```jsx
import { useState, useEffect } from 'react';
import contentService from '../content/content-service';
import { FileUpload, ContentGrid } from '../content/content-components';

function ContentPage() {
  const [content, setContent] = useState([]);

  useEffect(() => {
    loadContent();
  }, []);

  const loadContent = async () => {
    const result = await contentService.listContent();
    if (result.success) {
      setContent(result.contents);
    }
  };

  const handleUpload = async (file) => {
    const key = `user-content/${Date.now()}_${file.name}`;
    const result = await contentService.uploadFile(file, key);
    if (result.success) {
      loadContent(); // Refresh the list
    }
  };

  return (
    <div>
      <FileUpload onUploadComplete={handleUpload} />
      <ContentGrid content={content} />
    </div>
  );
}
```

## Deployment

### Development Deployment

```bash
# Build and deploy to dev environment
npm run deploy:dev
```

### Production Deployment

```bash
# Build and deploy to production environment
npm run deploy:prod
```

### Manual Deployment

```bash
# Build the application
npm run build

# Deploy using the deployment script
node deployment/deploy-to-s3.js
```

## Environment Variables Reference

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `NEXT_PUBLIC_AWS_REGION` | AWS region | `us-east-1` |
| `NEXT_PUBLIC_COGNITO_USER_POOL_ID` | Cognito User Pool ID | `us-east-1_XXXXXXXXX` |
| `NEXT_PUBLIC_COGNITO_USER_POOL_CLIENT_ID` | Cognito User Pool Client ID | `XXXXXXXXXXXXXXXXXXXXXXXXXX` |
| `NEXT_PUBLIC_S3_CONTENT_BUCKET` | S3 content bucket name | `my-app-dev-content-abc123` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NEXT_PUBLIC_COGNITO_IDENTITY_POOL_ID` | Cognito Identity Pool ID | - |
| `NEXT_PUBLIC_COGNITO_DOMAIN` | Cognito OAuth domain | - |
| `NEXT_PUBLIC_CLOUDFRONT_DISTRIBUTION_ID` | CloudFront distribution ID | - |
| `NEXT_PUBLIC_CUSTOM_DOMAIN` | Custom domain name | - |
| `NEXT_PUBLIC_ENVIRONMENT` | Environment name | `dev` |

### Deployment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `S3_WEBSITE_BUCKET` | S3 website bucket for deployment | - |
| `CLOUDFRONT_DISTRIBUTION_ID` | CloudFront distribution for invalidation | - |
| `BUILD_DIR` | Build output directory | `.next/out` |
| `DELETE_OLD_FILES` | Delete old files during deployment | `false` |

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   - Verify Cognito configuration in `.env.local`
   - Check that User Pool and Identity Pool are correctly configured
   - Ensure OAuth redirect URLs match your domain

2. **S3 Upload Errors**
   - Verify S3 bucket names in environment variables
   - Check that Cognito Identity Pool has S3 permissions
   - Ensure CORS is configured on the S3 bucket

3. **Deployment Issues**
   - Verify AWS credentials are configured
   - Check that deployment script has S3 and CloudFront permissions
   - Ensure bucket names and distribution IDs are correct

### Debug Mode

Enable debug mode by setting:

```env
NEXT_PUBLIC_ENABLE_DEBUG_MODE=true
```

This will enable additional logging and error details.

### Getting Help

1. Check the main project documentation in `/docs`
2. Review the Terraform outputs to ensure all resources are created
3. Check the browser console for client-side errors
4. Review server logs for API errors

## Security Considerations

1. **Environment Variables**: Never commit `.env.local` to version control
2. **Token Storage**: Tokens are stored securely by AWS Amplify
3. **HTTPS**: Always use HTTPS in production
4. **CORS**: Configure CORS properly on S3 buckets
5. **Presigned URLs**: Use appropriate expiration times
6. **Content Validation**: Validate file types and sizes on both client and server

## Performance Optimization

1. **Static Export**: Use Next.js static export for optimal S3 hosting
2. **CloudFront**: Leverage CloudFront for global content delivery
3. **Image Optimization**: Consider using Next.js Image component with CloudFront
4. **Bundle Analysis**: Use `npm run analyze` to analyze bundle size
5. **Caching**: Configure appropriate cache headers

## Next Steps

1. Customize the UI components to match your design
2. Add additional authentication features (MFA, social login)
3. Implement more content management features
4. Add monitoring and analytics
5. Set up CI/CD pipelines for automated deployment

For more detailed information, refer to the main project documentation and the individual component files.