# Final Integration Tests

This directory contains comprehensive end-to-end integration tests that validate the complete Terraform Next.js Infrastructure deployment. These tests fulfill the requirements for task 18 of the implementation plan.

## Overview

The final integration test suite validates:

1. **Complete Infrastructure Deployment** - End-to-end deployment of all infrastructure components
2. **Cross-Environment Isolation** - Proper separation between dev and prod environments
3. **Resource Separation** - Isolation between different resource types (website vs content buckets)
4. **GitHub Actions Workflows** - Validation of deployment pipeline configurations
5. **Security Penetration Testing** - Security validation of deployed infrastructure

## Test Files

### Core Integration Tests

- **`end_to_end_test.go`** - Complete infrastructure deployment tests
  - `TestCompleteInfrastructureDeployment` - Full deployment validation for both dev and prod
  - `TestCrossEnvironmentIsolation` - Environment isolation validation
  - `TestResourceSeparation` - Resource type separation validation
  - `TestDeploymentRollback` - Rollback capability testing
  - `TestFailureRecovery` - Recovery from deployment failures

- **`github_actions_test.go`** - GitHub Actions workflow validation
  - `TestGitHubActionsWorkflows` - Workflow structure and configuration validation
  - `TestWorkflowSyntax` - YAML syntax validation for all workflows
  - `TestWorkflowSecrets` - Secret reference validation
  - `TestWorkflowEnvironments` - GitHub environment configuration validation
  - `TestWorkflowArtifacts` - Artifact handling validation
  - `TestWorkflowNotifications` - Notification configuration validation

- **`security_penetration_test.go`** - Security penetration testing
  - `TestSecurityPenetrationTesting` - Comprehensive security validation
  - S3 bucket security testing (public access, encryption, policies)
  - CloudFront security testing (SSL/TLS, headers, origin access)
  - Cognito security testing (password policies, MFA, OAuth)
  - Network security testing (HTTPS enforcement, TLS configuration)
  - Encryption security testing (data at rest and in transit)

- **`integration_test_runner.go`** - Test suite orchestration
  - `TestFinalIntegrationSuite` - Complete test suite execution
  - `TestInfrastructureReadiness` - Infrastructure readiness validation
  - `TestComplianceValidation` - Compliance and operational requirements validation

### Test Execution Scripts

- **`run_final_integration_tests.sh`** - Unix/Linux test runner script
- **`run_final_integration_tests.ps1`** - Windows PowerShell test runner script

## Prerequisites

Before running the integration tests, ensure you have:

### Required Tools
- Go 1.21 or later
- AWS CLI configured with appropriate credentials
- Terraform 1.6+ installed
- Terragrunt 0.55+ installed

### AWS Permissions
Your AWS credentials must have permissions for:
- S3 (create/delete buckets, manage policies, encryption)
- CloudFront (create/delete distributions, manage configurations)
- Cognito (create/delete user pools, manage configurations)
- Route53 (create/delete hosted zones and records)
- ACM (create/delete certificates)
- IAM (manage roles and policies for testing)

### Environment Variables
```bash
export AWS_REGION=us-east-1                    # AWS region for testing
export TEST_ENVIRONMENT=ci                     # Test environment identifier
export CLEANUP_RESOURCES=true                  # Cleanup resources after tests
```

## Running the Tests

### Using Make (Recommended)

```bash
# Run all final integration tests
make test-final-integration

# Run specific test suites
make test-e2e                    # End-to-end deployment tests
make test-github-actions         # GitHub Actions workflow tests
make test-security-penetration   # Security penetration tests
make test-cross-environment      # Cross-environment isolation tests
make test-readiness             # Infrastructure readiness tests
```

### Using Test Runner Scripts

#### Unix/Linux/macOS
```bash
# Make script executable (if needed)
chmod +x test/run_final_integration_tests.sh

# Run all tests
./test/run_final_integration_tests.sh --suite all

# Run specific test suite
./test/run_final_integration_tests.sh --suite security --cleanup false

# Run with custom settings
./test/run_final_integration_tests.sh --suite e2e --region us-west-2 --timeout 45m
```

#### Windows PowerShell
```powershell
# Run all tests
.\test\run_final_integration_tests.ps1 -TestSuite all

# Run specific test suite
.\test\run_final_integration_tests.ps1 -TestSuite security -CleanupResources $false

# Run with custom settings
.\test\run_final_integration_tests.ps1 -TestSuite e2e -AWSRegion us-west-2 -Timeout 45m
```

### Using Go Test Directly

```bash
# Run all integration tests
go test -v -timeout 60m ./integration/...

# Run specific test
go test -v -timeout 30m -run TestCompleteInfrastructureDeployment ./integration/

# Run with short mode (skips long-running tests)
go test -v -short ./integration/...
```

## Test Configuration

### Test Suites Available

- **`all`** - Run all integration test suites (default)
- **`final-suite`** - Run the complete final integration test suite
- **`e2e`** - End-to-end infrastructure deployment tests
- **`github-actions`** - GitHub Actions workflow validation tests
- **`security`** - Security penetration tests
- **`cross-env`** - Cross-environment isolation tests
- **`readiness`** - Infrastructure readiness validation tests

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `AWS_REGION` | AWS region for testing | `us-east-1` |
| `TEST_ENVIRONMENT` | Test environment identifier | `ci` |
| `CLEANUP_RESOURCES` | Cleanup resources after tests | `true` |
| `TIMEOUT` | Test timeout duration | `60m` |
| `PARALLEL` | Number of parallel test executions | `1` |

### Resource Cleanup

By default, tests clean up all created resources. To preserve resources for debugging:

```bash
# Disable cleanup
export CLEANUP_RESOURCES=false
./test/run_final_integration_tests.sh --suite e2e
```

**Important**: When cleanup is disabled, you must manually delete resources to avoid AWS charges.

## Test Reports

The test runner generates comprehensive reports:

### Console Output
- Real-time test progress and results
- Color-coded status indicators
- Duration tracking for each test suite
- Summary statistics

### Markdown Report
Generated at `test-results/final-integration-test-report-YYYYMMDD-HHMMSS.md`:
- Detailed test results with status and duration
- Environment configuration details
- Troubleshooting guidance for failed tests
- Success rate and summary statistics

### JSON Report
Generated at `integration-test-report-{unique-id}.json`:
- Machine-readable test results
- Detailed timing information
- Environment metadata
- Individual test outcomes

### GitHub Actions Integration
When running in GitHub Actions, the test runner:
- Generates GitHub Actions job summaries
- Uploads test artifacts
- Provides actionable failure information
- Integrates with workflow status checks

## Test Architecture

### Test Structure
```
test/integration/
├── end_to_end_test.go              # Complete infrastructure deployment tests
├── github_actions_test.go          # GitHub Actions workflow validation
├── security_penetration_test.go    # Security penetration testing
├── integration_test_runner.go      # Test suite orchestration
├── run_final_integration_tests.sh  # Unix test runner
├── run_final_integration_tests.ps1 # Windows test runner
└── README.md                       # This file
```

### Test Flow
1. **Prerequisites Check** - Validate required tools and credentials
2. **Environment Setup** - Configure test environment and dependencies
3. **Infrastructure Deployment** - Deploy test infrastructure components
4. **Validation Testing** - Run comprehensive validation tests
5. **Security Testing** - Perform security penetration tests
6. **Cleanup** - Remove test resources (if enabled)
7. **Report Generation** - Generate detailed test reports

### Resource Naming
Tests use unique identifiers to prevent conflicts:
- Format: `{component}-{environment}-{unique-id}`
- Example: `nextjs-infra-e2e-dev-abc123`

## Troubleshooting

### Common Issues

#### AWS Credentials
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Configure credentials if needed
aws configure
```

#### Resource Conflicts
```bash
# Use unique test environment
export TEST_ENVIRONMENT="test-$(date +%s)"
```

#### Timeout Issues
```bash
# Increase timeout for slow environments
export TIMEOUT=90m
```

#### Permission Errors
Ensure your AWS user/role has all required permissions listed in the Prerequisites section.

### Debug Mode
```bash
# Run with verbose output and no cleanup
export CLEANUP_RESOURCES=false
go test -v -timeout 60m -run TestCompleteInfrastructureDeployment ./integration/
```

### Resource Inspection
When cleanup is disabled, you can inspect created resources in the AWS console:
- S3 buckets with test identifiers
- CloudFront distributions
- Cognito user pools
- Route53 hosted zones (if applicable)

## Integration with CI/CD

### GitHub Actions Integration
The tests are designed to integrate with GitHub Actions workflows:

```yaml
- name: Run Final Integration Tests
  run: |
    cd test
    ./run_final_integration_tests.sh --suite all --timeout 60m
  env:
    AWS_REGION: us-east-1
    TEST_ENVIRONMENT: ci
    CLEANUP_RESOURCES: true
```

### Local Development
For local development and debugging:

```bash
# Quick validation (skips long-running tests)
make test-short

# Full integration test suite
make test-final-integration

# Specific test with debugging
export CLEANUP_RESOURCES=false
go test -v -run TestSecurityPenetrationTesting ./integration/
```

## Contributing

When adding new integration tests:

1. Follow the existing test structure and naming conventions
2. Include proper cleanup logic
3. Add comprehensive error handling and validation
4. Update this README with new test descriptions
5. Ensure tests work in both local and CI environments

### Test Guidelines
- Use unique resource names with test identifiers
- Implement proper cleanup in defer statements
- Validate both positive and negative test cases
- Include security and compliance validations
- Provide clear error messages and troubleshooting guidance

## Requirements Mapping

This test suite fulfills the following requirements from the implementation plan:

### Requirement 9.1 - Essential Testing
- ✅ Provides essential tests without excessive complexity
- ✅ Focuses on critical infrastructure components
- ✅ Validates core functionality efficiently

### Requirement 9.2 - Security Validation
- ✅ Includes comprehensive security penetration testing
- ✅ Validates S3 bucket security configurations
- ✅ Tests CloudFront security headers and SSL/TLS
- ✅ Validates Cognito authentication security

### Requirement 9.3 - Quick Validation
- ✅ Supports quick validation with short mode
- ✅ Provides clear pass/fail indicators
- ✅ Offers actionable feedback for failures

### Task 18 Requirements
- ✅ **Complete Infrastructure Deployment** - End-to-end deployment validation
- ✅ **Cross-Environment Isolation** - Dev/prod environment separation testing
- ✅ **GitHub Actions Workflows** - Deployment pipeline validation
- ✅ **Security Penetration Testing** - Comprehensive security validation

The test suite provides comprehensive validation of the entire infrastructure while maintaining simplicity and actionable feedback as required by the project specifications.