# 🚀 Getting Started Guide

Welcome! This guide will get your Next.js infrastructure up and running in minutes.

## 📋 Prerequisites Checklist

- [ ] AWS account with admin access
- [ ] GitHub repository (fork or clone this repo)
- [ ] AWS CLI installed and configured
- [ ] Basic knowledge of Git

## 🎯 Step-by-Step Setup

### Step 1: Configure AWS Credentials

```bash
# Install AWS CLI if not already installed
# Then configure your credentials
aws configure

# Verify access
aws sts get-caller-identity
```

### Step 2: Setup GitHub Repository

1. **Fork or clone this repository**
2. **Add GitHub Secrets** (Settings → Secrets and variables → Actions):
   - `AWS_ACCESS_KEY_ID`: Your AWS access key
   - `AWS_SECRET_ACCESS_KEY`: Your AWS secret key

### Step 3: Bootstrap Infrastructure (One-time)

```bash
# Clone your repository
git clone https://github.com/yourusername/your-repo.git
cd your-repo

# Run bootstrap (creates S3 bucket for Terraform state)
cd bootstrap
./bootstrap.sh  # Linux/macOS
# OR
.\bootstrap.ps1  # Windows PowerShell
```

### Step 4: Configure Your Domain (Optional)

Edit `environments/dev/terragrunt.hcl` and `environments/prod/terragrunt.hcl`:

```hcl
locals {
  # Update these with your domain
  domain_name = "yourdomain.com"
  subdomain_dev = "dev.yourdomain.com"
  subdomain_prod = "yourdomain.com"
}
```

### Step 5: Deploy Development Environment

```bash
# Create a feature branch
git checkout -b setup/initial-deployment

# Push to trigger deployment
git add .
git commit -m "Initial infrastructure setup"
git push origin setup/initial-deployment
```

This will:
- ✅ Trigger security scanning
- ✅ Deploy to development environment
- ✅ Create a PR for review

### Step 6: Deploy Production Environment

```bash
# Merge to main branch
git checkout main
git merge setup/initial-deployment
git push origin main
```

This will:
- ✅ Trigger production deployment
- ✅ Require manual approval
- ✅ Deploy with safety checks

## 🎉 You're Done!

Your infrastructure is now deployed! Here's what you have:

### Development Environment
- 🌐 **Website**: `https://dev.yourdomain.com` (or CloudFront URL)
- 🔐 **Cognito**: User authentication ready
- 📦 **S3**: Static files and private content
- 📊 **Monitoring**: Basic CloudWatch monitoring

### Production Environment
- 🌐 **Website**: `https://yourdomain.com` (or CloudFront URL)
- 🔐 **Cognito**: Production user pool
- 📦 **S3**: Production storage
- 📊 **Monitoring**: Enhanced monitoring

## 🔧 Next Steps

### Deploy Your Next.js App

1. **Build your Next.js app**:
   ```bash
   npm run build
   npm run export  # For static export
   ```

2. **Upload to S3**:
   ```bash
   aws s3 sync out/ s3://your-website-bucket-name/
   ```

3. **Invalidate CloudFront**:
   ```bash
   aws cloudfront create-invalidation --distribution-id YOUR_DISTRIBUTION_ID --paths "/*"
   ```

### Configure Authentication

Your Cognito User Pool is ready! Get the details:

```bash
cd environments/dev/cognito
terragrunt output
```

Use these values in your Next.js app for authentication.

### Monitor Your Infrastructure

- **AWS Console**: Check CloudWatch for metrics
- **GitHub Security**: Review security scan results
- **Cost Explorer**: Monitor spending

## 🛠️ Customization

### Add/Remove Components

Edit the deployment workflows in `.github/workflows/` to modify which components are deployed:

```yaml
COMPONENTS="cognito s3-website s3-content route53-acm cloudfront monitoring"
```

### Modify Resources

Edit the Terraform modules in `modules/` to customize:
- S3 bucket settings
- CloudFront configurations
- Cognito user pool settings
- Monitoring thresholds

### Environment-Specific Settings

Customize each environment in `environments/dev/` and `environments/prod/`:
- Domain names
- Resource sizing
- Security settings
- Cost optimization

## 🆘 Troubleshooting

### Common Issues

**AWS Credentials Error**
```bash
# Check credentials
aws sts get-caller-identity

# Reconfigure if needed
aws configure
```

**Bootstrap Fails**
```bash
# Check if bucket name is unique
# Edit bootstrap/variables.tf if needed
```

**Deployment Fails**
- Check GitHub Actions logs
- Verify AWS permissions
- Review Terraform syntax

**Security Scan Fails**
- Check GitHub Security tab
- Review `.checkov.baseline` for approved exceptions

### Getting Help

1. **Check Logs**: GitHub Actions → Your workflow → Logs
2. **Security Issues**: GitHub Security tab
3. **AWS Resources**: AWS Console
4. **Manual Deployment**: Use `./scripts/deploy.sh` for local testing

## 📚 Learn More

- [GitHub Workflows README](.github/workflows/README.md)
- [Architecture Documentation](docs/ARCHITECTURE.md)
- [Module Usage Guide](docs/MODULE_USAGE.md)
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md)

## 🎊 Congratulations!

You now have a production-ready, secure, and cost-optimized infrastructure for your Next.js application with automated CI/CD pipelines!

Happy building! 🚀