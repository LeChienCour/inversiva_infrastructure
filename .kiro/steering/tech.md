# Technology Stack

## Core Technologies

### Infrastructure as Code
- **Terraform** (>= 1.0): Infrastructure provisioning and management
- **Terragrunt** (>= 0.45.0): DRY configuration and state management
- **AWS Provider** (~> 5.0): AWS resource management

### AWS Services
- **S3**: Static website hosting and private content storage
- **CloudFront**: Global CDN with Origin Access Control
- **Cognito**: User authentication (User Pools + Identity Pools)
- **Route 53**: DNS management and domain routing
- **ACM**: SSL/TLS certificate management
- **DynamoDB**: Terraform state locking (pay-per-request)
- **CloudWatch**: Monitoring and alerting

### CI/CD & Automation
- **GitHub Actions**: Automated deployment pipelines
- **Simple Scripts**: Local deployment utilities (bash/PowerShell)

### Security & Compliance
- **Checkov**: Security scanning with custom policies
- **AWS Security Hub**: Security findings aggregation
- **CloudTrail**: API logging and auditing

## Build System & Commands

### Prerequisites Installation
```bash
# Install required tools
aws configure                    # Configure AWS credentials
terraform --version             # Verify Terraform >= 1.0
terragrunt --version            # Verify Terragrunt >= 0.45.0
```

### Bootstrap Commands
```bash
# Initial setup (run once)
cd bootstrap
./bootstrap.sh                  # Linux/macOS
.\bootstrap.ps1                 # Windows PowerShell
```

### Automated Deployment Workflow
```bash
# Development - Automatic on push to develop
git checkout -b feature/my-feature
git push origin feature/my-feature  # Triggers auto-deployment

# Production - Automatic on push to main (with approval)
git checkout main
git push origin main  # Triggers production deployment
```

### Manual Deployment (Optional)
```bash
# Simple deployment script
./scripts/deploy.sh dev all plan     # Plan dev environment
./scripts/deploy.sh dev all apply    # Deploy dev environment
./scripts/deploy.sh prod cognito apply  # Deploy specific component

# Traditional Terragrunt (if needed)
cd environments/dev
terragrunt plan
terragrunt apply
terragrunt run-all apply
```

### Security Scanning (Automated)
```bash
# Automatic on every push/PR via GitHub Actions
# Manual security scan (if needed)
pip install checkov
checkov --config-file .checkov.yml --directory .
```

### Manual Deployment Scripts (Optional)
```bash
# Simple deployment utility (when CI/CD isn't available)
./scripts/deploy.sh [environment] [component] [action]
./scripts/deploy.ps1 [environment] [component] [action]

# Examples
./scripts/deploy.sh dev all plan      # Plan dev environment
./scripts/deploy.sh prod cognito apply  # Deploy specific component
```

### Validation & Formatting
```bash
# Validate Terraform syntax
terraform validate

# Format Terraform files
terraform fmt -recursive

# Terragrunt validation
terragrunt validate-inputs
```

## Project Conventions

### File Structure Standards
- **modules/**: Reusable Terraform modules (main.tf, variables.tf, outputs.tf, versions.tf)
- **environments/**: Environment-specific configurations (dev/, prod/)
- **bootstrap/**: State management infrastructure
- **scripts/**: Simple deployment utilities (.sh and .ps1 versions)
- **.github/workflows/**: Automated CI/CD pipelines

### Naming Conventions
- **Resources**: `${project_name}-${environment}-${service}-${random_suffix}`
- **Variables**: snake_case for Terraform, kebab-case for resource names
- **Tags**: Consistent tagging with Environment, Project, ManagedBy

### Environment Configuration
- **Development**: Cost-optimized, relaxed security, regional CloudFront
- **Production**: Performance-optimized, enhanced security, global CloudFront
- **Shared**: Route53 hosted zones, ACM certificates