# Project Structure

## Directory Organization

```
├── bootstrap/                 # Bootstrap infrastructure for state management
│   ├── main.tf               # S3 bucket and DynamoDB table for Terraform state
│   ├── variables.tf          # Bootstrap variables
│   ├── outputs.tf            # Bootstrap outputs
│   ├── bootstrap.sh          # Bootstrap script (Linux/macOS)
│   ├── bootstrap.ps1         # Bootstrap script (Windows)
│   └── README.md             # Bootstrap documentation
├── environments/             # Environment-specific configurations
│   ├── dev/                  # Development environment
│   │   ├── terragrunt.hcl    # Environment-specific config
│   │   ├── cognito/          # Cognito module deployment
│   │   ├── s3-website/       # S3 website module deployment
│   │   ├── s3-content/       # S3 content module deployment
│   │   ├── cloudfront/       # CloudFront module deployment
│   │   ├── route53-acm/      # Route53 & ACM module deployment
│   │   └── monitoring/       # Monitoring module deployment
│   └── prod/                 # Production environment (same structure as dev)
├── modules/                  # Custom Terraform modules
│   ├── cognito/              # Cognito authentication module
│   ├── s3-website/           # S3 static website hosting module
│   ├── s3-content/           # S3 private content storage module
│   ├── cloudfront/           # CloudFront distribution module
│   ├── route53-acm/          # Route 53 and ACM certificate module
│   └── monitoring/           # CloudWatch monitoring and alerting module
├── scripts/                  # Simple deployment utilities (optional)
│   ├── deploy.sh             # Universal deployment script (Linux/macOS)
│   ├── deploy.ps1            # Universal deployment script (Windows)
│   └── README.md             # Script usage documentation
├── .github/workflows/        # Automated CI/CD pipelines
│   ├── deploy-dev.yml        # Development deployment workflow
│   ├── deploy-prod.yml       # Production deployment workflow
│   ├── security-scan.yml     # Security scanning workflow
│   └── README.md             # Pipeline documentation
├── docs/                     # Project documentation
│   ├── ARCHITECTURE.md       # System architecture overview
│   ├── MODULE_USAGE.md       # Module usage examples
│   └── TROUBLESHOOTING.md    # Common issues and solutions
├── .checkov/                 # Security scanning configuration
│   └── custom_policies/      # Organization-specific security policies
├── terragrunt.hcl            # Root Terragrunt configuration
├── GETTING_STARTED.md        # Step-by-step setup guide
└── README.md                 # Project overview and quick start
```

## Module Structure Standards

Each Terraform module follows a consistent structure:

```
modules/{module-name}/
├── main.tf                   # Primary resource definitions
├── variables.tf              # Input variables with validation
├── outputs.tf                # Output values for other modules
├── versions.tf               # Provider version constraints
├── iam.tf                    # IAM policies and roles (if applicable)
├── README.md                 # Module documentation
└── examples/                 # Usage examples
    └── basic/                # Basic usage example
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Environment Structure

Each environment contains module deployments with Terragrunt configuration:

```
environments/{env}/
├── terragrunt.hcl            # Environment-specific configuration
├── README.md                 # Environment deployment guide
├── {module-name}/            # Module deployment directory
│   └── terragrunt.hcl        # Module-specific Terragrunt config
└── CONFIGURATION_APPROACH.md # Environment configuration documentation
```

## Deployment Dependencies

### Phase 1: Foundation
1. **bootstrap/** - State management infrastructure (run once)
2. **route53-acm/** - DNS and SSL certificates
3. **cognito/** - User authentication

### Phase 2: Storage and Distribution
4. **s3-website/** - Static website hosting
5. **s3-content/** - Private content storage
6. **cloudfront/** - CDN distribution (depends on route53-acm, s3-website)

### Phase 3: Monitoring
7. **monitoring/** - CloudWatch monitoring and alerting

## Configuration Patterns

### Root Configuration (terragrunt.hcl)
- Common variables and tags
- Remote state configuration
- Provider generation
- AWS account and region settings

### Environment Configuration
- Environment-specific variables
- Domain configuration
- Cost optimization settings
- Security policy variations

### Module Configuration
- Module source path
- Input variable mapping
- Dependency declarations
- Environment-specific overrides

## File Naming Conventions

### Terraform Files
- `main.tf` - Primary resource definitions
- `variables.tf` - Input variables
- `outputs.tf` - Output values
- `versions.tf` - Provider constraints
- `iam.tf` - IAM-specific resources
- `locals.tf` - Local values (if needed)

### Scripts
- Minimal set: Only essential deployment utilities
- Dual platform support: `.sh` (Unix) and `.ps1` (PowerShell)
- Universal deployment script: `deploy.sh`/`deploy.ps1`
- Consistent parameter pattern: `[environment] [component] [action]`

### Documentation
- `README.md` - Primary documentation
- `ARCHITECTURE.md` - System design
- `TROUBLESHOOTING.md` - Issue resolution
- ALL_CAPS for major documentation files

## Resource Naming Patterns

### AWS Resources
- Format: `${project_name}-${environment}-${service}-${random_suffix}`
- Example: `terraform-nextjs-infrastructure-dev-website-a1b2c3d4`

### Terraform Resources
- snake_case for resource names
- Descriptive prefixes: `aws_s3_bucket.website`, `aws_cognito_user_pool.main`

### Variables and Outputs
- snake_case for all variable names
- Descriptive names: `enable_versioning`, `bucket_domain_name`
- Consistent prefixes for related variables