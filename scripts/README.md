# Helper Scripts and Utilities

This directory contains helper scripts and utilities for managing the Terraform Next.js infrastructure project. These scripts provide convenient tools for development, testing, cost monitoring, and resource management.

## Scripts Overview

### 1. Presigned URL Utilities

**Files:** `presigned-url-utils.sh`, `presigned-url-utils.ps1`

Utilities for generating and testing S3 presigned URLs for secure content access.

**Features:**
- Generate presigned URLs for existing S3 objects
- Upload files and generate presigned URLs
- Test presigned URL accessibility
- List objects in content buckets
- Auto-detect bucket names from Terragrunt outputs

**Usage Examples:**
```bash
# Generate presigned URL for existing object
./scripts/presigned-url-utils.sh generate -e dev -k "users/user123/document.pdf"

# Upload file and generate presigned URL
./scripts/presigned-url-utils.sh upload -e dev -f "./test-file.txt" -k "users/user123/test-file.txt"

# Test a presigned URL
./scripts/presigned-url-utils.sh test -u "https://bucket.s3.amazonaws.com/object?..."
```

### 2. Cost Monitoring and Reporting

**Files:** `cost-monitor.sh`, `cost-monitor.ps1`

Tools for monitoring AWS costs and generating cost reports.

**Features:**
- Generate cost reports with customizable time periods
- Show cost breakdown by AWS service
- Analyze cost trends over time
- Check budget status and alerts
- Provide cost optimization recommendations

**Usage Examples:**
```bash
# Generate monthly cost report
./scripts/cost-monitor.sh report -d 30 -g MONTHLY

# Show cost breakdown by service for dev environment
./scripts/cost-monitor.sh breakdown -e dev -d 7

# Show cost trends for the last 90 days
./scripts/cost-monitor.sh trends -d 90

# Check budget status
./scripts/cost-monitor.sh budget
```

### 3. Environment Cleanup and Resource Management

**Files:** `env-cleanup.sh`, `env-cleanup.ps1`

Utilities for cleaning up and managing AWS resources across environments.

**Features:**
- List all resources in an environment
- Validate resource state and configuration
- Backup important data before cleanup
- Clean up specific resource types (S3, Cognito, CloudFront)
- Destroy entire environments with safety checks

**Usage Examples:**
```bash
# List all resources in dev environment
./scripts/env-cleanup.sh list -e dev

# Clean up S3 buckets in dev environment with backup
./scripts/env-cleanup.sh cleanup -e dev -r s3 -b

# Destroy entire dev environment (with confirmation)
./scripts/env-cleanup.sh destroy -e dev

# Dry run of production cleanup
./scripts/env-cleanup.sh cleanup -e prod -r all --dry-run
```

### 4. Local Development and Testing

**Files:** `local-dev.sh`, `local-dev.ps1`

Tools for local development workflow and infrastructure testing.

**Features:**
- Set up local development environment
- Run Terragrunt plan and apply operations
- Execute infrastructure tests (unit, integration, smoke)
- Validate and format Terraform configuration
- Generate documentation
- Clean up temporary files

**Usage Examples:**
```bash
# Set up local development environment
./scripts/local-dev.sh setup

# Plan changes for dev environment
./scripts/local-dev.sh plan -e dev

# Apply changes to specific module
./scripts/local-dev.sh apply -e dev -m s3-website

# Run all tests
./scripts/local-dev.sh test -e dev

# Validate and format code
./scripts/local-dev.sh validate -f
./scripts/local-dev.sh format
```

### 5. Existing Scripts

**Files:** `dev-deploy.sh`, `dev-deploy.ps1`, `manage-security-exceptions.sh`, `manage-security-exceptions.ps1`

Previously created scripts for deployment and security management.

## Prerequisites

### Required Tools

All scripts require the following tools to be installed and configured:

1. **AWS CLI** - For AWS API interactions
   ```bash
   # Install AWS CLI
   # Configure credentials
   aws configure
   ```

2. **Terraform** - For infrastructure validation and formatting
   ```bash
   # Install Terraform
   terraform --version
   ```

3. **Terragrunt** - For infrastructure deployment and management
   ```bash
   # Install Terragrunt
   terragrunt --version
   ```

### Optional Tools

Some scripts provide enhanced functionality with these optional tools:

1. **jq** - For JSON processing (improves cost monitoring output)
2. **pre-commit** - For code quality hooks
3. **terraform-docs** - For documentation generation
4. **make** - For running test suites

## Platform Support

All scripts are provided in both Unix shell (`.sh`) and PowerShell (`.ps1`) versions:

- **Unix/Linux/macOS**: Use `.sh` scripts
- **Windows**: Use `.ps1` scripts

### Windows Usage

On Windows, run PowerShell scripts with:
```powershell
.\scripts\script-name.ps1 [command] [options]
```

### Unix/Linux/macOS Usage

On Unix-like systems, run shell scripts with:
```bash
./scripts/script-name.sh [command] [options]
```

## Common Options

Most scripts support these common options:

- `-e, --environment ENV` - Specify environment (dev/prod)
- `-v, --verbose` - Enable verbose output
- `-h, --help` - Show help information
- `-f, --force` - Force operations without confirmation (use with caution)
- `-d, --dry-run` - Show what would be done without executing

## Safety Features

### Confirmation Prompts

Destructive operations require explicit confirmation:
- Environment destruction
- Resource cleanup
- Infrastructure apply operations

### Backup Capabilities

Scripts that modify or destroy resources offer backup options:
- Terraform state backup
- S3 metadata backup
- Configuration backup

### Dry Run Mode

Most scripts support dry-run mode to preview changes:
```bash
./scripts/env-cleanup.sh cleanup -e dev -r all --dry-run
```

## Integration with Project Structure

The scripts are designed to work with the project's structure:

```
├── environments/
│   ├── dev/
│   └── prod/
├── modules/
├── scripts/          # This directory
├── test/
└── terragrunt.hcl
```

Scripts automatically:
- Detect environment configurations
- Read Terragrunt outputs
- Navigate project structure
- Integrate with existing workflows

## Error Handling

All scripts include comprehensive error handling:

- **Dependency Checks**: Verify required tools are installed
- **AWS Configuration**: Check AWS CLI credentials
- **Path Validation**: Ensure required directories exist
- **Operation Validation**: Verify operations before execution
- **Graceful Failures**: Provide clear error messages and recovery suggestions

## Logging and Output

Scripts provide structured output with:

- **Color-coded Messages**: Info (blue), success (green), warning (yellow), error (red)
- **Progress Indicators**: Clear indication of operation progress
- **Verbose Mode**: Detailed output for troubleshooting
- **Log Files**: Some operations create log files in `logs/` directory

## Best Practices

### Development Workflow

1. **Setup**: Run `local-dev.sh setup` once
2. **Validate**: Use `local-dev.sh validate` before changes
3. **Format**: Use `local-dev.sh format -f` to fix formatting
4. **Plan**: Use `local-dev.sh plan` to preview changes
5. **Test**: Use `local-dev.sh test` after changes

### Cost Management

1. **Regular Monitoring**: Run `cost-monitor.sh report` weekly
2. **Trend Analysis**: Use `cost-monitor.sh trends` monthly
3. **Budget Alerts**: Set up budgets with `cost-monitor.sh budget`
4. **Optimization**: Review recommendations with `cost-monitor.sh optimize`

### Resource Management

1. **Regular Cleanup**: Clean up dev resources regularly
2. **Backup First**: Always backup before destructive operations
3. **Validate State**: Use `env-cleanup.sh validate` to check health
4. **Dry Run**: Test cleanup operations with `--dry-run` first

## Troubleshooting

### Common Issues

1. **AWS Credentials**: Ensure AWS CLI is configured
2. **Tool Versions**: Check that all required tools are installed
3. **Permissions**: Verify AWS permissions for required operations
4. **Network**: Ensure internet connectivity for AWS API calls

### Getting Help

Each script provides detailed help:
```bash
./scripts/script-name.sh help
```

For project-specific issues, refer to:
- `docs/TROUBLESHOOTING.md`
- `docs/DEVELOPMENT_DEPLOYMENT.md`
- Individual module README files

## Contributing

When adding new scripts:

1. **Dual Platform**: Provide both `.sh` and `.ps1` versions
2. **Consistent Interface**: Follow existing command/option patterns
3. **Error Handling**: Include comprehensive error checking
4. **Documentation**: Update this README with new script information
5. **Testing**: Test on both Unix and Windows platforms

## Security Considerations

- **Credentials**: Scripts use AWS CLI credentials, never hardcode secrets
- **Confirmation**: Destructive operations require explicit confirmation
- **Logging**: Avoid logging sensitive information
- **Permissions**: Follow principle of least privilege for AWS permissions