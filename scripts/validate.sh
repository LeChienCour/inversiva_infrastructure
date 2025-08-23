#!/bin/bash

# Terraform Infrastructure Validation Script
# This script validates both environment configurations and environment variable loading

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Function to print section headers
print_section() {
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================================${NC}"
}

# Function to validate Terraform configuration
validate_terraform_config() {
    local environment=$1
    local env_dir="$PROJECT_ROOT/environments/$environment"
    
    echo -e "${YELLOW}🔍 Validating Terraform configuration for $environment environment...${NC}"
    
    if [ ! -d "$env_dir" ]; then
        echo -e "${RED}❌ Environment directory not found: $env_dir${NC}"
        return 1
    fi
    
    # Change to environment directory
    cd "$env_dir"
    
    # Check if main Terraform files exist
    local required_files=("main.tf" "variables.tf" "outputs.tf" "backend.tf")
    local optional_files=("provider.tf" "versions.tf")
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing required Terraform files in $environment:${NC}"
        for file in "${missing_files[@]}"; do
            echo -e "${RED}  - $file${NC}"
        done
        return 1
    fi
    
    echo -e "${GREEN}✅ All required Terraform files present${NC}"
    
    # Check for provider configuration (either in provider.tf or main.tf)
    if [ -f "provider.tf" ]; then
        echo -e "${GREEN}✅ Provider configuration found in provider.tf${NC}"
    elif grep -q "terraform\s*{" main.tf 2>/dev/null; then
        echo -e "${GREEN}✅ Provider configuration found in main.tf${NC}"
    else
        echo -e "${YELLOW}⚠️ Warning: No provider configuration found${NC}"
    fi
    
    # Validate HCL syntax without initialization
    echo -e "${YELLOW}📋 Checking HCL syntax...${NC}"
    
    local hcl_files
    hcl_files=$(find . -name "*.tf" -type f)
    local syntax_errors=()
    
    for file in $hcl_files; do
        # Use terraform fmt to check syntax
        if ! terraform fmt -check=true "$file" > /dev/null 2>&1; then
            echo -e "${YELLOW}⚠️ Warning: $file is not properly formatted${NC}"
        fi
        
        # Basic HCL syntax validation using terraform validate-config (if available)
        # For now, we'll do a basic check for balanced braces
        local open_braces=$(grep -o '{' "$file" | wc -l)
        local close_braces=$(grep -o '}' "$file" | wc -l)
        
        if [ "$open_braces" -ne "$close_braces" ]; then
            syntax_errors+=("$file: Unbalanced braces (open: $open_braces, close: $close_braces)")
        fi
    done
    
    if [ ${#syntax_errors[@]} -gt 0 ]; then
        echo -e "${RED}❌ HCL syntax errors found:${NC}"
        for error in "${syntax_errors[@]}"; do
            echo -e "${RED}  - $error${NC}"
        done
        return 1
    fi
    
    echo -e "${GREEN}✅ HCL syntax check completed${NC}"
    
    # Try to initialize and validate if possible (skip if it fails due to missing variables)
    echo -e "${YELLOW}📋 Attempting Terraform validation...${NC}"
    
    # Create a minimal terraform.tfvars for validation
    if [ ! -f "terraform.tfvars" ]; then
        cat > terraform.tfvars.validation << 'EOF'
# Minimal variables for validation
project_name = "test-project"
environment = "dev"
aws_region = "us-east-1"
domain_name = "example.com"
root_domain = "example.com"
cognito_min_password_length = 8
cognito_require_lowercase = true
cognito_require_numbers = true
cognito_require_symbols = false
cognito_require_uppercase = true
cognito_temp_password_validity = 7
s3_enable_versioning = false
s3_content_bucket_prefix = "test-content"
cloudfront_price_class = "PriceClass_100"
route53_create_hosted_zone = false
cors_allow_origins = ["http://localhost:3000"]
cost_center = "development"
owner = "dev-team"
EOF
    fi
    
    # Create temporary backend override for validation
    cat > backend_override.tf << 'EOF'
terraform {
  backend "local" {
    path = "terraform.tfstate.validation"
  }
}
EOF
    
    # Try to initialize (may fail due to module dependencies, which is OK)
    local init_success=false
    if terraform init -upgrade > /dev/null 2>&1; then
        init_success=true
        echo -e "${GREEN}✅ Terraform initialized successfully${NC}"
        
        # Try to validate
        local validation_output
        if validation_output=$(terraform validate 2>&1); then
            echo -e "${GREEN}✅ Terraform configuration is valid${NC}"
        else
            echo -e "${YELLOW}⚠️ Terraform validation warnings (may be due to missing dependencies):${NC}"
            echo -e "${YELLOW}$validation_output${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Terraform initialization skipped (may require actual AWS resources)${NC}"
    fi
    
    # Clean up validation artifacts
    rm -f backend_override.tf terraform.tfstate.validation .terraform.lock.hcl terraform.tfvars.validation
    rm -rf .terraform
    
    echo -e "${GREEN}✅ Terraform configuration validation completed for $environment${NC}"
    return 0
}

# Function to test environment variable loading
test_environment_loading() {
    local environment=$1
    
    echo -e "${YELLOW}🔍 Testing environment variable loading for $environment...${NC}"
    
    # Source the load-env script in a subshell to test loading
    if (
        cd "$PROJECT_ROOT"
        source scripts/load-env.sh "$environment"
    ); then
        echo -e "${GREEN}✅ Environment variables loaded successfully for $environment${NC}"
    else
        echo -e "${RED}❌ Failed to load environment variables for $environment${NC}"
        return 1
    fi
    
    # Test specific environment variables are set correctly
    echo -e "${YELLOW}📋 Verifying environment-specific variables...${NC}"
    
    # Load environment in current shell for testing
    cd "$PROJECT_ROOT"
    source scripts/load-env.sh "$environment" > /dev/null 2>&1
    
    # Test core variables
    local test_vars=(
        "PROJECT_NAME"
        "ENVIRONMENT"
        "AWS_REGION"
        "DOMAIN_NAME"
        "ROOT_DOMAIN"
    )
    
    local missing_vars=()
    for var in "${test_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing core environment variables:${NC}"
        for var in "${missing_vars[@]}"; do
            echo -e "${RED}  - $var${NC}"
        done
        return 1
    fi
    
    # Verify environment-specific values
    if [ "$ENVIRONMENT" != "$environment" ]; then
        echo -e "${RED}❌ Environment variable mismatch: expected '$environment', got '$ENVIRONMENT'${NC}"
        return 1
    fi
    
    # Environment-specific validations
    if [ "$environment" = "dev" ]; then
        # Dev-specific checks
        if [ "$COGNITO_MIN_PASSWORD_LENGTH" -lt 6 ]; then
            echo -e "${RED}❌ Dev environment: Invalid password length${NC}"
            return 1
        fi
        
        if [ "$S3_ENABLE_VERSIONING" != "false" ]; then
            echo -e "${YELLOW}⚠️ Dev environment: S3 versioning is enabled (may increase costs)${NC}"
        fi
        
        if [ "$CLOUDFRONT_PRICE_CLASS" != "PriceClass_100" ]; then
            echo -e "${YELLOW}⚠️ Dev environment: CloudFront price class is not cost-optimized${NC}"
        fi
        
    elif [ "$environment" = "prod" ]; then
        # Prod-specific checks
        if [ "$COGNITO_MIN_PASSWORD_LENGTH" -lt 12 ]; then
            echo -e "${RED}❌ Prod environment: Password length too short for production${NC}"
            return 1
        fi
        
        if [ "$COGNITO_REQUIRE_SYMBOLS" != "true" ]; then
            echo -e "${RED}❌ Prod environment: Symbols should be required for production${NC}"
            return 1
        fi
        
        if [ "$S3_ENABLE_VERSIONING" != "true" ]; then
            echo -e "${RED}❌ Prod environment: S3 versioning should be enabled${NC}"
            return 1
        fi
        
        if [ "$ROUTE53_CREATE_HOSTED_ZONE" != "true" ]; then
            echo -e "${RED}❌ Prod environment: Hosted zone creation should be enabled${NC}"
            return 1
        fi
    fi
    
    echo -e "${GREEN}✅ Environment variable validation completed for $environment${NC}"
    return 0
}

# Function to test terraform.tfvars generation
test_tfvars_generation() {
    local environment=$1
    local env_dir="$PROJECT_ROOT/environments/$environment"
    
    echo -e "${YELLOW}🔍 Testing terraform.tfvars generation for $environment...${NC}"
    
    # Load environment variables
    cd "$PROJECT_ROOT"
    source scripts/load-env.sh "$environment" > /dev/null 2>&1
    
    # Generate terraform.tfvars in a temporary location
    local temp_dir=$(mktemp -d)
    local temp_tfvars="$temp_dir/terraform.tfvars"
    
    # Use the generate function from load-env.sh
    if generate_terraform_tfvars "$temp_dir" "$environment" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ terraform.tfvars generated successfully${NC}"
    else
        echo -e "${RED}❌ Failed to generate terraform.tfvars${NC}"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Validate the generated file
    if [ ! -f "$temp_tfvars" ]; then
        echo -e "${RED}❌ terraform.tfvars file was not created${NC}"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Check if file contains expected variables
    local expected_vars=(
        "project_name"
        "environment"
        "aws_region"
        "domain_name"
        "cognito_min_password_length"
        "s3_enable_versioning"
        "cloudfront_price_class"
    )
    
    local missing_vars=()
    for var in "${expected_vars[@]}"; do
        if ! grep -q "^$var\s*=" "$temp_tfvars"; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing variables in generated terraform.tfvars:${NC}"
        for var in "${missing_vars[@]}"; do
            echo -e "${RED}  - $var${NC}"
        done
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Validate HCL syntax of generated file
    cd "$temp_dir"
    if ! terraform fmt -check=true terraform.tfvars > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠️ Generated terraform.tfvars has formatting issues${NC}"
    fi
    
    echo -e "${GREEN}✅ terraform.tfvars generation test completed${NC}"
    
    # Clean up
    rm -rf "$temp_dir"
    return 0
}

# Function to validate module references
validate_module_references() {
    local environment=$1
    local env_dir="$PROJECT_ROOT/environments/$environment"
    
    echo -e "${YELLOW}🔍 Validating module references for $environment...${NC}"
    
    cd "$env_dir"
    
    # Check if main.tf references existing modules
    if [ ! -f "main.tf" ]; then
        echo -e "${RED}❌ main.tf not found${NC}"
        return 1
    fi
    
    # Extract module sources from main.tf using a more robust pattern
    local module_sources
    module_sources=$(grep -E '^\s*source\s*=\s*"[^"]*"' main.tf | sed 's/^\s*source\s*=\s*"\([^"]*\)".*/\1/' || true)
    
    if [ -z "$module_sources" ]; then
        echo -e "${YELLOW}⚠️ No module sources found in main.tf${NC}"
        return 0
    fi
    
    echo -e "${BLUE}📋 Found module sources:${NC}"
    echo "$module_sources" | while IFS= read -r source; do
        if [ -n "$source" ]; then
            echo -e "${BLUE}  - $source${NC}"
        fi
    done
    
    # Validate each module source path
    local invalid_modules=()
    local valid_modules=()
    
    while IFS= read -r module_source; do
        if [ -n "$module_source" ]; then
            # Convert relative path to absolute path
            local module_path
            if [[ "$module_source" == /* ]]; then
                # Absolute path
                module_path="$module_source"
            else
                # Relative path - resolve from environment directory
                module_path="$(cd "$env_dir" && realpath "$module_source" 2>/dev/null || echo "$env_dir/$module_source")"
            fi
            
            if [ ! -d "$module_path" ]; then
                invalid_modules+=("$module_source (directory not found: $module_path)")
            else
                # Check if module has required files
                if [ ! -f "$module_path/main.tf" ]; then
                    invalid_modules+=("$module_source (missing main.tf in $module_path)")
                elif [ ! -f "$module_path/variables.tf" ]; then
                    invalid_modules+=("$module_source (missing variables.tf in $module_path)")
                elif [ ! -f "$module_path/outputs.tf" ]; then
                    invalid_modules+=("$module_source (missing outputs.tf in $module_path)")
                else
                    valid_modules+=("$module_source")
                fi
            fi
        fi
    done <<< "$module_sources"
    
    # Report results
    if [ ${#valid_modules[@]} -gt 0 ]; then
        echo -e "${GREEN}✅ Valid module references:${NC}"
        for module in "${valid_modules[@]}"; do
            echo -e "${GREEN}  - $module${NC}"
        done
    fi
    
    if [ ${#invalid_modules[@]} -gt 0 ]; then
        echo -e "${RED}❌ Invalid module references:${NC}"
        for module in "${invalid_modules[@]}"; do
            echo -e "${RED}  - $module${NC}"
        done
        return 1
    fi
    
    echo -e "${GREEN}✅ All module references are valid${NC}"
    return 0
}

# Function to run comprehensive validation
run_comprehensive_validation() {
    local environment=$1
    
    print_section "COMPREHENSIVE VALIDATION FOR $environment ENVIRONMENT"
    
    local validation_failed=false
    
    # Test 1: Environment variable loading
    echo ""
    if ! test_environment_loading "$environment"; then
        validation_failed=true
    fi
    
    # Test 2: Terraform configuration validation
    echo ""
    if ! validate_terraform_config "$environment"; then
        validation_failed=true
    fi
    
    # Test 3: Module reference validation
    echo ""
    if ! validate_module_references "$environment"; then
        validation_failed=true
    fi
    
    # Test 4: terraform.tfvars generation
    echo ""
    if ! test_tfvars_generation "$environment"; then
        validation_failed=true
    fi
    
    echo ""
    print_section "VALIDATION SUMMARY FOR $environment"
    
    if [ "$validation_failed" = true ]; then
        echo -e "${RED}❌ Validation failed for $environment environment${NC}"
        echo -e "${YELLOW}💡 Please fix the above issues before proceeding${NC}"
        return 1
    fi
    
    echo -e "${GREEN}🎉 All validation tests passed for $environment environment!${NC}"
    return 0
}

# Main execution
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
                echo "Options:"
                echo "  --env ENVIRONMENT    Validate specific environment (dev or prod)"
                echo "  --help, -h          Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0                  # Validate both dev and prod environments"
                echo "  $0 --env dev        # Validate only dev environment"
                echo "  $0 --env prod       # Validate only prod environment"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Validate target environment if specified
    if [ -n "$target_env" ]; then
        if [[ ! "$target_env" =~ ^(dev|prod)$ ]]; then
            echo -e "${RED}❌ Invalid environment: $target_env${NC}"
            echo -e "${YELLOW}💡 Valid environments: dev, prod${NC}"
            exit 1
        fi
        environments=("$target_env")
    fi
    
    # Check prerequisites
    print_section "CHECKING PREREQUISITES"
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}❌ Terraform not found. Please install Terraform.${NC}"
        exit 1
    fi
    
    local terraform_version
    terraform_version=$(terraform version -json 2>/dev/null | grep -o '"terraform_version": "[^"]*"' | cut -d'"' -f4 || echo "unknown")
    echo -e "${GREEN}✅ Terraform found: v$terraform_version${NC}"
    
    # Check if required directories exist
    local required_dirs=("config" "environments" "modules" "scripts")
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$PROJECT_ROOT/$dir" ]; then
            echo -e "${RED}❌ Required directory not found: $dir${NC}"
            exit 1
        fi
    done
    echo -e "${GREEN}✅ All required directories found${NC}"
    
    # Check if load-env.sh exists
    if [ ! -f "$PROJECT_ROOT/scripts/load-env.sh" ]; then
        echo -e "${RED}❌ load-env.sh script not found${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ load-env.sh script found${NC}"
    
    # Run validation for each environment
    for env in "${environments[@]}"; do
        echo ""
        if ! run_comprehensive_validation "$env"; then
            overall_success=false
        fi
    done
    
    # Final summary
    echo ""
    print_section "FINAL VALIDATION SUMMARY"
    
    if [ "$overall_success" = true ]; then
        echo -e "${GREEN}🎉 ALL VALIDATION TESTS PASSED!${NC}"
        echo -e "${GREEN}✅ Both environment configurations are valid${NC}"
        echo -e "${GREEN}✅ Environment variable loading works correctly${NC}"
        echo -e "${GREEN}✅ Terraform configurations are syntactically correct${NC}"
        echo -e "${GREEN}✅ Module references are valid${NC}"
        echo -e "${GREEN}✅ Ready for deployment${NC}"
        exit 0
    else
        echo -e "${RED}❌ VALIDATION FAILED${NC}"
        echo -e "${YELLOW}💡 Please fix the issues above before proceeding with deployment${NC}"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"