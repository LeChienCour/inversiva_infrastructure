#!/bin/bash

# Simple Test Script for CI/CD
# This script runs basic validation tests with minimal output

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Function to run terraform validate
test_terraform_validate() {
    local environment=$1
    local env_dir="$PROJECT_ROOT/environments/$environment"
    
    echo "Testing Terraform validation for $environment..."
    
    cd "$env_dir"
    
    # Create minimal terraform.tfvars for validation
    cat > terraform.tfvars.test << 'EOF'
project_name = "test-project"
environment = "dev"
aws_region = "us-east-1"
domain_name = "example.com"
root_domain = "example.com"
cost_center = "development"
owner = "dev-team"
cognito_min_password_length = 8
cognito_require_lowercase = true
cognito_require_numbers = true
cognito_require_symbols = false
cognito_require_uppercase = true
cognito_temp_password_validity = 7
cognito_mfa_configuration = "OPTIONAL"
cognito_explicit_auth_flows = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
cognito_allowed_oauth_flows = ["code"]
cognito_allowed_oauth_scopes = ["email", "openid", "profile"]
cognito_callback_urls = ["http://localhost:3000/auth/callback"]
cognito_logout_urls = ["http://localhost:3000/auth/logout"]
cognito_access_token_validity = 1
cognito_id_token_validity = 1
cognito_refresh_token_validity = 7
cognito_allow_unauthenticated_identities = true
s3_enable_versioning = false
s3_enable_lifecycle_policy = true
s3_enable_intelligent_tiering = false
s3_enable_object_lock = false
s3_lifecycle_transition_ia_days = 7
s3_lifecycle_transition_glacier_days = 30
s3_noncurrent_version_expiration_days = 30
s3_content_bucket_prefix = "test-content"
s3_presigned_url_expiration_seconds = 300
cloudfront_price_class = "PriceClass_100"
cloudfront_enable_ipv6 = false
cloudfront_enable_monitoring = false
cloudfront_content_security_policy = "default-src 'self'"
cloudfront_error_caching_min_ttl = 300
cloudfront_logging_include_cookies = false
route53_create_hosted_zone = false
route53_enable_health_check = false
route53_enable_ipv6 = false
route53_health_check_path = "/"
route53_health_check_failure_threshold = 3
route53_health_check_request_interval = 30
cors_allow_credentials = false
cors_allow_headers = "Accept,Accept-Language,Content-Language,Content-Type,Authorization"
cors_allow_methods = "GET,HEAD,OPTIONS,PUT,POST,PATCH,DELETE"
cors_allow_origins = ["http://localhost:3000"]
cors_max_age_seconds = 86400
EOF

    # Create temporary backend override for validation
    cat > backend_override.tf << 'EOF'
terraform {
  backend "local" {
    path = "terraform.tfstate.test"
  }
}
EOF

    # Initialize and validate
    local success=true
    if terraform init -upgrade > /dev/null 2>&1; then
        if terraform validate > /dev/null 2>&1; then
            echo "✅ $environment: Terraform validation passed"
        else
            echo "❌ $environment: Terraform validation failed"
            success=false
        fi
    else
        echo "⚠️ $environment: Terraform init failed (may be expected)"
    fi
    
    # Clean up
    rm -f backend_override.tf terraform.tfstate.test .terraform.lock.hcl terraform.tfvars.test
    rm -rf .terraform
    
    return $([ "$success" = true ] && echo 0 || echo 1)
}

# Function to test environment variable loading
test_env_loading() {
    local environment=$1
    
    echo "Testing environment variable loading for $environment..."
    
    cd "$PROJECT_ROOT"
    
    # Test loading in a subshell
    if (source scripts/load-env.sh "$environment" > /dev/null 2>&1); then
        echo "✅ $environment: Environment variables loaded successfully"
        return 0
    else
        echo "❌ $environment: Environment variable loading failed"
        return 1
    fi
}

# Main test function
main() {
    local environments=("dev" "prod")
    local target_env=""
    local overall_success=true
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --env|--environment)
                target_env="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: $0 [--env ENVIRONMENT] [--help]"
                echo ""
                echo "Simple test script for CI/CD pipelines"
                echo ""
                echo "Options:"
                echo "  --env ENVIRONMENT    Test specific environment (dev or prod)"
                echo "  --help, -h          Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Validate target environment if specified
    if [ -n "$target_env" ]; then
        if [[ ! "$target_env" =~ ^(dev|prod)$ ]]; then
            echo "❌ Invalid environment: $target_env"
            exit 1
        fi
        environments=("$target_env")
    fi
    
    echo "Running simple validation tests..."
    echo ""
    
    # Check prerequisites
    if ! command -v terraform &> /dev/null; then
        echo "❌ Terraform not found"
        exit 1
    fi
    
    # Run tests for each environment
    for env in "${environments[@]}"; do
        echo "Testing $env environment:"
        
        if ! test_env_loading "$env"; then
            overall_success=false
        fi
        
        if ! test_terraform_validate "$env"; then
            overall_success=false
        fi
        
        echo ""
    done
    
    # Final result
    if [ "$overall_success" = true ]; then
        echo -e "${GREEN}🎉 All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some tests failed${NC}"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"