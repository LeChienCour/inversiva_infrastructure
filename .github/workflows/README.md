# 🚀 Simple CI/CD Pipelines

Easy-to-use GitHub Actions workflows for deploying your Terraform infrastructure.

## 📋 Available Workflows

### 🔧 Development Deployment (`deploy-dev.yml`)
- **Triggers**: Push to `develop`, `dev`, `feature/*` branches
- **What it does**: Plans and deploys to development environment
- **Manual options**: Choose components and actions via workflow dispatch

### 🚀 Production Deployment (`deploy-prod.yml`)
- **Triggers**: Push to `main`/`master` branches
- **What it does**: Plans and deploys to production with approval gates
- **Manual options**: Emergency deployments and component selection

### 🔒 Security Scanning (`security-scan.yml`)
- **Triggers**: All pushes, PRs, and daily schedule
- **What it does**: Scans infrastructure for security issues
- **Manual options**: Adjust severity thresholds

## 🎯 Quick Start

### 1. Setup Secrets
Add these to your GitHub repository secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### 2. Deploy to Development
```bash
git checkout -b feature/my-feature
# Make your changes
git push origin feature/my-feature
# Creates PR → triggers security scan and dev deployment
```

### 3. Deploy to Production
```bash
git checkout main
git merge feature/my-feature
git push origin main
# Triggers production deployment with approval
```

## 🔧 Manual Deployments

### Deploy Specific Components
1. Go to **Actions** tab
2. Select **Deploy Development** or **Deploy Production**
3. Click **Run workflow**
4. Choose:
   - **Component**: `all`, `cognito`, `s3-website`, etc.
   - **Action**: `plan`, `apply`, or `destroy`

### Emergency Production Deployment
1. Go to **Actions** → **Deploy Production**
2. Set **Emergency** to `true`
3. Skips approval gates for critical fixes

## 📊 Workflow Features

### Development Environment
- ✅ Automatic deployment on push to `develop`
- ✅ Security scanning with relaxed thresholds
- ✅ PR comments with deployment status
- ✅ Component-specific deployments

### Production Environment
- ✅ Manual approval required (unless emergency)
- ✅ Strict security scanning
- ✅ State backup before changes
- ✅ Deployment verification
- ✅ Emergency bypass option

### Security Scanning
- ✅ Runs on every push and PR
- ✅ Daily scheduled scans
- ✅ SARIF upload to GitHub Security tab
- ✅ Configurable severity thresholds
- ✅ PR comments with results

## 🛠️ Customization

### Modify Components
Edit the workflow files to add/remove components:
```yaml
COMPONENTS="cognito s3-website s3-content route53-acm cloudfront monitoring"
```

### Change Security Thresholds
Adjust in `.github/workflows/security-scan.yml`:
```yaml
severity:
  default: 'CRITICAL'  # Change to HIGH, MEDIUM, or LOW
```

### Add Notifications
Add Slack webhook URL to repository secrets as `SLACK_WEBHOOK_URL` for production notifications.

## 🔍 Troubleshooting

### Common Issues

**AWS Credentials Error**
- Verify secrets are set correctly
- Check IAM permissions

**Security Scan Failures**
- Review issues in Security tab
- Update `.checkov.baseline` for approved exceptions

**Deployment Failures**
- Check workflow logs
- Verify Terraform syntax
- Ensure dependencies are deployed in order

### Getting Help
1. Check workflow logs in Actions tab
2. Review security findings in Security tab
3. Use manual workflow dispatch for debugging
4. Check AWS console for resource status

## 📈 Best Practices

### Development Workflow
1. Create feature branches
2. Make small, focused changes
3. Let CI/CD handle deployments
4. Review security scan results

### Production Workflow
1. Always review plans before approval
2. Use emergency bypass sparingly
3. Monitor deployments closely
4. Keep security baselines updated

### Security
1. Review security scan results regularly
2. Update approved exceptions quarterly
3. Keep Checkov and policies current
4. Monitor GitHub Security tab

## 🎉 That's It!

Your infrastructure is now ready for easy, automated deployments. The pipelines handle the complexity while keeping things simple and secure.

Happy deploying! 🚀