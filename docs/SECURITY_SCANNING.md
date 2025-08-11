# Security Scanning with Checkov

This document describes the comprehensive security scanning implementation using Checkov for the Terraform Next.js infrastructure project.

## Overview

The security scanning system provides automated security analysis of Infrastructure as Code (IaC) using Checkov, with custom policies, exception management, and integration into CI/CD workflows.

## Components

### 1. Checkov Configuration (`.checkov.yml`)

The main configuration file that defines:
- Frameworks to scan (Terraform)
- Directories to include/exclude
- Custom policies location
- Output formats
- Skip checks and exceptions
- Severity mappings

### 2. Custom Security Policies (`.checkov/custom_policies/`)

Organization-specific security policies:

#### S3 Bucket Naming Convention (`s3_bucket_naming.py`)
- **Check ID**: `CKV2_AWS_S3_NAMING`
- **Purpose**: Enforces consistent S3 bucket naming
- **Requirements**: 
  - Must include environment (dev/prod)
  - Must be lowercase
  - Must not exceed 63 characters
  - Must follow pattern: `^[a-z0-9][a-z0-9-]*-(dev|prod|test)-[a-z0-9-]+$`

#### Cognito Security (`cognito_security.py`)
- **Check ID**: `CKV2_AWS_COGNITO_PASSWORD`
  - Enforces strong password policies
  - Minimum length >= 12 characters
  - Requires uppercase, lowercase, numbers, and symbols
- **Check ID**: `CKV2_AWS_COGNITO_MFA`
  - Ensures MFA is enabled for production environments
  - Based on resource tags

#### CloudFront Security (`cloudfront_security.py`)
- **Check ID**: `CKV2_AWS_CLOUDFRONT_HEADERS`
  - Validates security headers configuration
  - Ensures response headers policy is configured
- **Check ID**: `CKV2_AWS_CLOUDFRONT_TLS`
  - Enforces minimum TLS 1.2
  - Validates acceptable protocol versions

### 3. Security Baseline (`.checkov.baseline`)

JSON file containing approved security exceptions with:
- Detailed justifications
- Approval information
- Review dates
- Environment-specific exceptions
- Resource-specific exceptions

### 4. GitHub Actions Integration

#### Development Environment (`deploy-dev.yml`)
- Enhanced security scanning with custom policies
- Fails only on CRITICAL severity issues
- Supports security bypass for emergencies
- Uploads scan results to GitHub Security tab

#### Production Environment (`deploy-prod.yml`)
- Comprehensive security scanning
- Fails on CRITICAL or HIGH severity issues
- Emergency bypass requires manual approval
- Slack notifications for security failures
- Extended artifact retention (90 days)

#### Dedicated Security Workflow (`security-scan.yml`)
- Standalone security scanning
- Multiple output formats (CLI, SARIF, JSON, JUnit)
- Configurable severity thresholds
- PR comments with scan results
- Detailed security reports

### 5. Exception Management Scripts

#### Bash Script (`scripts/manage-security-exceptions.sh`)
For Linux/macOS environments:
- List current exceptions
- Add new exceptions with approval workflow
- Remove outdated exceptions
- Review exceptions needing renewal
- Generate security reports
- Validate baseline integrity

#### PowerShell Script (`scripts/manage-security-exceptions.ps1`)
For Windows environments:
- Same functionality as bash script
- Native PowerShell implementation
- Windows-compatible file operations

## Usage

### Running Security Scans

#### Manual Scan
```bash
# Full scan with all policies
checkov --config-file .checkov.yml --directory .

# Scan specific directory
checkov --config-file .checkov.yml --directory modules/

# Scan with custom severity threshold
checkov --config-file .checkov.yml --directory . --check-type CKV2_AWS
```

#### GitHub Actions
```bash
# Trigger security scan workflow
gh workflow run security-scan.yml

# Trigger with specific parameters
gh workflow run security-scan.yml \
  -f scan_type=modules-only \
  -f severity_threshold=HIGH \
  -f fail_on_severity=CRITICAL
```

### Managing Security Exceptions

#### List Current Exceptions
```bash
# Linux/macOS
./scripts/manage-security-exceptions.sh list

# Windows
.\scripts\manage-security-exceptions.ps1 list
```

#### Add New Exception
```bash
# Linux/macOS
./scripts/manage-security-exceptions.sh add \
  --check-id CKV_AWS_18 \
  --environment dev \
  --justification "Cost optimization for development" \
  --approved-by "Security Team"

# Windows
.\scripts\manage-security-exceptions.ps1 add \
  -CheckId CKV_AWS_18 \
  -Environment dev \
  -Justification "Cost optimization for development" \
  -ApprovedBy "Security Team"
```

#### Review Exceptions Needing Renewal
```bash
# Linux/macOS
./scripts/manage-security-exceptions.sh review

# Windows
.\scripts\manage-security-exceptions.ps1 review
```

#### Generate Security Report
```bash
# Linux/macOS
./scripts/manage-security-exceptions.sh report

# Windows
.\scripts\manage-security-exceptions.ps1 report
```

### Security Bypass Procedures

#### Development Environment
1. Include `[security-bypass]` in commit message
2. Bypass is automatically approved for non-critical issues
3. Critical issues still require manual review

#### Production Environment (Emergency Only)
1. Include `[emergency-security-bypass]` in commit message
2. Use manual workflow dispatch with `skip_approval: true`
3. Requires additional approvals in real implementation
4. Triggers immediate Slack notifications
5. Requires follow-up security review

## Security Scan Results

### Severity Levels
- **CRITICAL**: Immediate action required, blocks deployment
- **HIGH**: Significant security risk, blocks production deployment
- **MEDIUM**: Moderate risk, requires review but doesn't block deployment
- **LOW**: Minor issues, informational only

### Output Formats
- **CLI**: Human-readable console output
- **SARIF**: GitHub Security tab integration
- **JSON**: Machine-readable for automation
- **JUnit**: Test result integration

### Artifact Storage
- Development: 7 days retention
- Production: 90 days retention
- Includes detailed logs, scan results, and security reports

## Approved Exceptions

### Cost Optimization Exceptions
- **CKV_AWS_18/19**: S3 access logging disabled in development
- **CKV_AWS_144**: S3 cross-region replication disabled

### Organization-Level Services
- **CKV_AWS_35/36**: CloudTrail managed at organization level
- **CKV_AWS_20**: GuardDuty managed at organization level

### Architecture-Specific Exceptions
- **CKV_AWS_76**: VPC Flow Logs not applicable for serverless architecture

## Best Practices

### Exception Management
1. **Minimize Exceptions**: Only create exceptions when absolutely necessary
2. **Document Thoroughly**: Provide detailed justifications
3. **Regular Reviews**: Review exceptions quarterly
4. **Time-bound**: Set appropriate review dates
5. **Environment-specific**: Use different rules for dev vs prod

### Security Scanning
1. **Fail Fast**: Run security scans early in the pipeline
2. **Multiple Formats**: Use different output formats for different audiences
3. **Trend Analysis**: Monitor security posture over time
4. **Custom Policies**: Implement organization-specific requirements
5. **Baseline Management**: Keep baseline current and accurate

### Emergency Procedures
1. **Document Bypasses**: Always document why bypass was needed
2. **Follow-up Required**: Schedule immediate security review
3. **Limit Scope**: Only bypass specific checks, not entire scan
4. **Notification**: Ensure security team is notified immediately
5. **Remediation Plan**: Create plan to address bypassed issues

## Troubleshooting

### Common Issues

#### Checkov Installation
```bash
# Install specific version
pip install checkov==3.1.34

# Verify installation
checkov --version
```

#### Custom Policy Errors
```bash
# Validate Python syntax
python -m py_compile .checkov/custom_policies/*.py

# Test custom policies
checkov --external-checks-dir .checkov/custom_policies/ --check CKV2_AWS --directory modules/
```

#### Baseline File Issues
```bash
# Validate JSON syntax
jq empty .checkov.baseline

# Regenerate baseline
checkov --config-file .checkov.yml --directory . --create-baseline
```

### GitHub Actions Debugging
1. Check workflow logs for detailed error messages
2. Verify Checkov version compatibility
3. Ensure all required files are present
4. Check file permissions and paths
5. Validate JSON syntax in configuration files

## Integration with Other Tools

### GitHub Security Tab
- SARIF results automatically uploaded
- Security alerts created for findings
- Integration with GitHub Advanced Security features

### Slack Notifications
- Production deployment failures
- Emergency bypass activations
- Security scan summaries

### Terraform/Terragrunt
- Pre-deployment validation
- Integration with plan/apply workflows
- State file security validation

## Monitoring and Metrics

### Key Metrics
- Number of security findings by severity
- Exception approval rate
- Time to remediation
- Security scan coverage
- False positive rate

### Reporting
- Weekly security scan summaries
- Monthly exception reviews
- Quarterly security posture reports
- Annual security baseline updates

## Future Enhancements

### Planned Improvements
1. **Dynamic Policy Updates**: Automatic policy updates from security team
2. **Risk Scoring**: Weighted risk scores based on environment and resource type
3. **Integration Testing**: Security validation in integration tests
4. **Compliance Mapping**: Map checks to compliance frameworks (SOC2, PCI-DSS)
5. **Machine Learning**: Anomaly detection for unusual security patterns

### Tool Integration
1. **SIEM Integration**: Forward security events to SIEM systems
2. **Vulnerability Scanning**: Integration with container and dependency scanners
3. **Policy as Code**: Version-controlled security policies
4. **Automated Remediation**: Auto-fix for common security issues
5. **Risk Assessment**: Integration with risk management tools

## Support and Contacts

### Security Team
- **Email**: security@organization.com
- **Slack**: #security-team
- **On-call**: security-oncall@organization.com

### Documentation
- **Checkov Docs**: https://www.checkov.io/
- **AWS Security**: https://aws.amazon.com/security/
- **Terraform Security**: https://learn.hashicorp.com/tutorials/terraform/security

### Emergency Contacts
- **Security Incident**: security-incident@organization.com
- **Infrastructure Team**: infrastructure@organization.com
- **DevOps On-call**: devops-oncall@organization.com