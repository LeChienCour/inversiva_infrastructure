# 🛠️ Deployment Scripts

Simple deployment utilities for local development and troubleshooting.

## 📋 Available Scripts

### `deploy.sh` / `deploy.ps1`
Universal deployment script for all environments and components.

**Usage:**
```bash
# Linux/macOS
./scripts/deploy.sh [environment] [component] [action]

# Windows PowerShell
.\scripts\deploy.ps1 [environment] [component] [action]
```

**Parameters:**
- `environment`: `dev` or `prod` (default: `dev`)
- `component`: `all`, `cognito`, `s3-website`, `s3-content`, `cloudfront`, `route53-acm`, `monitoring` (default: `all`)
- `action`: `plan`, `apply`, `destroy`, `output` (default: `plan`)

## 🎯 Examples

```bash
# Plan all components in dev environment
./scripts/deploy.sh dev all plan

# Deploy specific component to dev
./scripts/deploy.sh dev cognito apply

# Plan production deployment
./scripts/deploy.sh prod all plan

# Get outputs from production
./scripts/deploy.sh prod all output

# Destroy dev environment (careful!)
./scripts/deploy.sh dev all destroy
```

## 🤖 When to Use Scripts vs CI/CD

### Use CI/CD Pipelines (Recommended)
- ✅ Regular deployments
- ✅ Production deployments
- ✅ Team collaboration
- ✅ Security scanning
- ✅ Approval workflows

### Use Scripts (Optional)
- 🔧 Local development
- 🐛 Troubleshooting
- 🧪 Testing changes locally
- 🚨 Emergency fixes
- 📊 Getting outputs quickly

## 📚 More Information

For automated deployments, see [GitHub Workflows](../.github/workflows/README.md).

For step-by-step setup, see [Getting Started Guide](../GETTING_STARTED.md).