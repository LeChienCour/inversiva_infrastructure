# Infrastructure Testing Framework

This directory contains comprehensive tests for the Terraform Next.js infrastructure using Terratest.

## Test Structure

- `modules/` - Unit tests for individual Terraform modules
- `integration/` - Integration tests for complete environment deployments
- `smoke/` - Smoke tests for basic functionality validation
- `security/` - Security validation tests
- `cost/` - Cost optimization verification tests

## Prerequisites

1. Go 1.21 or later
2. AWS CLI configured with appropriate credentials
3. Terraform and Terragrunt installed
4. Test AWS account with permissions to create resources

## Running Tests

### All Tests
```bash
cd test
go test -v ./...
```

### Specific Test Categories
```bash
# Module unit tests
go test -v ./modules/...

# Integration tests
go test -v ./integration/...

# Smoke tests
go test -v ./smoke/...

# Security tests
go test -v ./security/...

# Cost optimization tests
go test -v ./cost/...
```

### Individual Tests
```bash
# Test specific module
go test -v ./modules/s3_website_test.go

# Test with timeout
go test -v -timeout 30m ./integration/...
```

## Test Configuration

Tests use environment variables for configuration:

- `AWS_REGION` - AWS region for testing (default: us-east-1)
- `TEST_ENVIRONMENT` - Environment name for testing (default: test)
- `CLEANUP_RESOURCES` - Whether to cleanup resources after tests (default: true)

## Test Data

Test data and fixtures are stored in the `fixtures/` directory and are used to provide consistent test inputs across different test scenarios.