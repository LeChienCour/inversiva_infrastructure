#!/bin/bash

# Environment variable loading utility for Terraform deployment
# Usage: source scripts/load-env.sh [environment]

set -e

# Function to load environment variables from .env files
load_environment_variables() {
    local environment=${1:-dev}
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_root="$(cd "$script_dir/.." && pwd)"
    local config_dir="$project_root/config"
    
    # Colors for output
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local RED='\033[0;31m'
    local NC='\033[0m' # No Color
    
    echo -e "${YELLOW}📋 Loading environment variables for: $environment${NC}"
    
    # Load common environment variables first
    local common_env_file="$config_dir/common.env"
    if [ -f "$common_env_file" ]; then
        echo -e "${GREEN}✅ Loading common variables from: $common_env_file${NC}"
        set -a  # automatically export all variables
        source "$common_env_file"
        set +a
    else
        echo -e "${RED}❌ Common environment file not found: $common_env_file${NC}"
        return 1
    fi
    
    # Load environment-specific variables
    local env_file="$config_dir/${environment}.env"
    if [ -f "$env_file" ]; then
        echo -e "${GREEN}✅ Loading $environment variables from: $env_file${NC}"
        set -a  # automatically export all variables
        source "$env_file"
        set +a
    else
        echo -e "${RED}❌ Environment file not found: $env_file${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Environment variables loaded successfully${NC}"
    return 0
}

# Function to validate required environment variables
validate_environment_variables() {
    local environment=${1:-dev}
    
    # Colors for output
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local RED='\033[0;31m'
    local BLUE='\033[0;34m'
    local NC='\033[0m' # No Color
    
    echo -e "${YELLOW}🔍 Validating required environment variables...${NC}"
    
    # Core required variables for all environments
    local core_required_vars=(
        "PROJECT_NAME"
        "AWS_REGION"
        "ENVIRONMENT"
        "DOMAIN_NAME"
        "ROOT_DOMAIN"
        "MANAGED_BY"
        "CREATED_BY"
    )
    
    # Cognito required variables
    local cognito_required_vars=(
        "COGNITO_MIN_PASSWORD_LENGTH"
        "COGNITO_REQUIRE_LOWERCASE"
        "COGNITO_REQUIRE_NUMBERS"
        "COGNITO_REQUIRE_SYMBOLS"
        "COGNITO_REQUIRE_UPPERCASE"
        "COGNITO_TEMP_PASSWORD_VALIDITY"
    )
    
    # S3 required variables
    local s3_required_vars=(
        "S3_ENABLE_VERSIONING"
        "S3_CONTENT_BUCKET_PREFIX"
    )
    
    # CloudFront required variables
    local cloudfront_required_vars=(
        "CLOUDFRONT_PRICE_CLASS"
    )
    
    # Route53 required variables
    local route53_required_vars=(
        "ROUTE53_CREATE_HOSTED_ZONE"
    )
    
    # CORS required variables
    local cors_required_vars=(
        "CORS_ALLOW_ORIGINS"
        "CORS_ALLOW_CREDENTIALS"
        "CORS_ALLOW_HEADERS"
        "CORS_ALLOW_METHODS"
        "CORS_MAX_AGE_SECONDS"
    )
    
    # Additional required variables
    local additional_required_vars=(
        "COST_CENTER"
        "OWNER"
        "COGNITO_MFA_CONFIGURATION"
        "COGNITO_EXPLICIT_AUTH_FLOWS"
        "COGNITO_ALLOWED_OAUTH_FLOWS"
        "COGNITO_ALLOWED_OAUTH_SCOPES"
        "COGNITO_CALLBACK_URLS"
        "COGNITO_LOGOUT_URLS"
        "COGNITO_ACCESS_TOKEN_VALIDITY"
        "COGNITO_ID_TOKEN_VALIDITY"
        "COGNITO_REFRESH_TOKEN_VALIDITY"
        "COGNITO_ALLOW_UNAUTHENTICATED_IDENTITIES"
        "S3_ENABLE_LIFECYCLE_POLICY"
        "S3_ENABLE_INTELLIGENT_TIERING"
        "S3_ENABLE_OBJECT_LOCK"
        "S3_LIFECYCLE_TRANSITION_IA_DAYS"
        "S3_LIFECYCLE_TRANSITION_GLACIER_DAYS"
        "S3_NONCURRENT_VERSION_EXPIRATION_DAYS"
        "S3_PRESIGNED_URL_EXPIRATION_SECONDS"
        "CLOUDFRONT_ENABLE_IPV6"
        "CLOUDFRONT_ENABLE_MONITORING"
        "CLOUDFRONT_CONTENT_SECURITY_POLICY"
        "CLOUDFRONT_ERROR_CACHING_MIN_TTL"
        "CLOUDFRONT_LOGGING_INCLUDE_COOKIES"
        "ROUTE53_ENABLE_HEALTH_CHECK"
        "ROUTE53_ENABLE_IPV6"
        "ROUTE53_HEALTH_CHECK_PATH"
        "ROUTE53_HEALTH_CHECK_FAILURE_THRESHOLD"
        "ROUTE53_HEALTH_CHECK_REQUEST_INTERVAL"
    )
    
    # Combine all required variables
    local all_required_vars=(
        "${core_required_vars[@]}"
        "${cognito_required_vars[@]}"
        "${s3_required_vars[@]}"
        "${cloudfront_required_vars[@]}"
        "${route53_required_vars[@]}"
        "${cors_required_vars[@]}"
        "${additional_required_vars[@]}"
    )
    
    local missing_vars=()
    local invalid_vars=()
    
    # Check for missing variables
    echo -e "${BLUE}📋 Checking for missing variables...${NC}"
    for var in "${all_required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    # Validate variable formats and values
    echo -e "${BLUE}📋 Validating variable formats and values...${NC}"
    
    # Validate environment
    if [ -n "$ENVIRONMENT" ]; then
        if [[ ! "$ENVIRONMENT" =~ ^(dev|prod)$ ]]; then
            invalid_vars+=("ENVIRONMENT: must be 'dev' or 'prod', got '$ENVIRONMENT'")
        fi
    fi
    
    # Validate AWS region format
    if [ -n "$AWS_REGION" ]; then
        if [[ ! "$AWS_REGION" =~ ^[a-z]{2}-[a-z]+-[0-9]+$ ]]; then
            invalid_vars+=("AWS_REGION: invalid format, got '$AWS_REGION'")
        fi
    fi
    
    # Validate domain names (allow subdomains)
    if [ -n "$DOMAIN_NAME" ]; then
        if [[ ! "$DOMAIN_NAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$ ]]; then
            invalid_vars+=("DOMAIN_NAME: invalid domain format, got '$DOMAIN_NAME'")
        fi
    fi
    
    if [ -n "$ROOT_DOMAIN" ]; then
        if [[ ! "$ROOT_DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$ ]]; then
            invalid_vars+=("ROOT_DOMAIN: invalid domain format, got '$ROOT_DOMAIN'")
        fi
    fi
    
    # Validate Cognito password length
    if [ -n "$COGNITO_MIN_PASSWORD_LENGTH" ]; then
        if ! [[ "$COGNITO_MIN_PASSWORD_LENGTH" =~ ^[0-9]+$ ]] || [ "$COGNITO_MIN_PASSWORD_LENGTH" -lt 6 ] || [ "$COGNITO_MIN_PASSWORD_LENGTH" -gt 99 ]; then
            invalid_vars+=("COGNITO_MIN_PASSWORD_LENGTH: must be a number between 6 and 99, got '$COGNITO_MIN_PASSWORD_LENGTH'")
        fi
    fi
    
    # Validate Cognito temp password validity
    if [ -n "$COGNITO_TEMP_PASSWORD_VALIDITY" ]; then
        if ! [[ "$COGNITO_TEMP_PASSWORD_VALIDITY" =~ ^[0-9]+$ ]] || [ "$COGNITO_TEMP_PASSWORD_VALIDITY" -lt 1 ] || [ "$COGNITO_TEMP_PASSWORD_VALIDITY" -gt 365 ]; then
            invalid_vars+=("COGNITO_TEMP_PASSWORD_VALIDITY: must be a number between 1 and 365, got '$COGNITO_TEMP_PASSWORD_VALIDITY'")
        fi
    fi
    
    # Validate boolean values
    local boolean_vars=(
        "COGNITO_REQUIRE_LOWERCASE"
        "COGNITO_REQUIRE_NUMBERS"
        "COGNITO_REQUIRE_SYMBOLS"
        "COGNITO_REQUIRE_UPPERCASE"
        "S3_ENABLE_VERSIONING"
        "ROUTE53_CREATE_HOSTED_ZONE"
    )
    
    for var in "${boolean_vars[@]}"; do
        if [ -n "${!var}" ]; then
            if [[ ! "${!var}" =~ ^(true|false)$ ]]; then
                invalid_vars+=("$var: must be 'true' or 'false', got '${!var}'")
            fi
        fi
    done
    
    # Validate CloudFront price class
    if [ -n "$CLOUDFRONT_PRICE_CLASS" ]; then
        if [[ ! "$CLOUDFRONT_PRICE_CLASS" =~ ^(PriceClass_100|PriceClass_200|PriceClass_All)$ ]]; then
            invalid_vars+=("CLOUDFRONT_PRICE_CLASS: must be 'PriceClass_100', 'PriceClass_200', or 'PriceClass_All', got '$CLOUDFRONT_PRICE_CLASS'")
        fi
    fi
    
    # Validate S3 content bucket prefix
    if [ -n "$S3_CONTENT_BUCKET_PREFIX" ]; then
        if [[ ! "$S3_CONTENT_BUCKET_PREFIX" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]]; then
            invalid_vars+=("S3_CONTENT_BUCKET_PREFIX: invalid S3 bucket name format, got '$S3_CONTENT_BUCKET_PREFIX'")
        fi
    fi
    
    # Validate CORS origins format
    if [ -n "$CORS_ALLOW_ORIGINS" ]; then
        # Check if it contains valid URLs
        if [[ ! "$CORS_ALLOW_ORIGINS" =~ ^https?:// ]]; then
            invalid_vars+=("CORS_ALLOW_ORIGINS: must contain valid HTTP/HTTPS URLs, got '$CORS_ALLOW_ORIGINS'")
        fi
    fi
    
    # Environment-specific validations
    if [ "$environment" = "prod" ]; then
        # Production-specific validations
        if [ -n "$COGNITO_MIN_PASSWORD_LENGTH" ] && [ "$COGNITO_MIN_PASSWORD_LENGTH" -lt 12 ]; then
            invalid_vars+=("COGNITO_MIN_PASSWORD_LENGTH: production environment requires minimum 12 characters, got '$COGNITO_MIN_PASSWORD_LENGTH'")
        fi
        
        if [ "$COGNITO_REQUIRE_SYMBOLS" = "false" ]; then
            invalid_vars+=("COGNITO_REQUIRE_SYMBOLS: production environment requires symbols to be enabled")
        fi
        
        if [ "$S3_ENABLE_VERSIONING" = "false" ]; then
            invalid_vars+=("S3_ENABLE_VERSIONING: production environment requires versioning to be enabled")
        fi
        
        if [ "$ROUTE53_CREATE_HOSTED_ZONE" = "false" ]; then
            invalid_vars+=("ROUTE53_CREATE_HOSTED_ZONE: production environment requires hosted zone creation")
        fi
    fi
    
    # Report validation results
    local validation_failed=false
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing required environment variables:${NC}"
        for var in "${missing_vars[@]}"; do
            echo -e "${RED}  - $var${NC}"
        done
        validation_failed=true
    fi
    
    if [ ${#invalid_vars[@]} -gt 0 ]; then
        echo -e "${RED}❌ Invalid environment variable values:${NC}"
        for var in "${invalid_vars[@]}"; do
            echo -e "${RED}  - $var${NC}"
        done
        validation_failed=true
    fi
    
    if [ "$validation_failed" = true ]; then
        echo -e "${RED}❌ Environment variable validation failed${NC}"
        echo -e "${YELLOW}💡 Please check your config/${environment}.env and config/common.env files${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ All environment variables are valid${NC}"
    return 0
}

# Function to validate AWS credentials and permissions
validate_aws_credentials() {
    # Colors for output
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local RED='\033[0;31m'
    local BLUE='\033[0;34m'
    local NC='\033[0m' # No Color
    
    echo -e "${YELLOW}🔍 Validating AWS credentials and permissions...${NC}"
    
    # Check if AWS CLI is available
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ AWS CLI not found. Please install AWS CLI.${NC}"
        return 1
    fi
    
    # Check if AWS credentials are configured
    echo -e "${BLUE}📋 Checking AWS credentials...${NC}"
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}❌ AWS credentials not configured or invalid.${NC}"
        echo -e "${YELLOW}💡 Please run 'aws configure' to set up your credentials.${NC}"
        return 1
    fi
    
    # Get caller identity information
    local caller_identity
    caller_identity=$(aws sts get-caller-identity 2>/dev/null)
    if [ $? -eq 0 ]; then
        local account_id=$(echo "$caller_identity" | grep -o '"Account": "[^"]*"' | cut -d'"' -f4)
        local user_arn=$(echo "$caller_identity" | grep -o '"Arn": "[^"]*"' | cut -d'"' -f4)
        echo -e "${GREEN}✅ AWS credentials valid${NC}"
        echo -e "${BLUE}   Account ID: $account_id${NC}"
        echo -e "${BLUE}   User/Role: $user_arn${NC}"
    else
        echo -e "${RED}❌ Failed to get AWS caller identity${NC}"
        return 1
    fi
    
    # Check if the configured region matches the environment variable
    local configured_region
    configured_region=$(aws configure get region 2>/dev/null)
    if [ -n "$configured_region" ] && [ "$configured_region" != "$AWS_REGION" ]; then
        echo -e "${YELLOW}⚠️ Warning: AWS CLI region ($configured_region) differs from environment variable ($AWS_REGION)${NC}"
        echo -e "${YELLOW}   Using environment variable: $AWS_REGION${NC}"
    fi
    
    # Test basic AWS permissions
    echo -e "${BLUE}📋 Testing basic AWS permissions...${NC}"
    
    # Test S3 permissions
    if ! aws s3 ls &> /dev/null; then
        echo -e "${YELLOW}⚠️ Warning: Limited S3 permissions detected${NC}"
    fi
    
    # Test IAM permissions (basic)
    if ! aws iam get-user &> /dev/null && ! aws sts get-caller-identity --query 'Arn' --output text | grep -q 'role'; then
        echo -e "${YELLOW}⚠️ Warning: Limited IAM permissions detected${NC}"
    fi
    
    echo -e "${GREEN}✅ AWS credentials validation completed${NC}"
    return 0
}

# Function to validate Terraform prerequisites
validate_terraform_prerequisites() {
    # Colors for output
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local RED='\033[0;31m'
    local BLUE='\033[0;34m'
    local NC='\033[0m' # No Color
    
    echo -e "${YELLOW}🔍 Validating Terraform prerequisites...${NC}"
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}❌ Terraform not found. Please install Terraform.${NC}"
        echo -e "${YELLOW}💡 Visit: https://www.terraform.io/downloads.html${NC}"
        return 1
    fi
    
    # Check Terraform version
    local terraform_version
    terraform_version=$(terraform version -json 2>/dev/null | grep -o '"terraform_version": "[^"]*"' | cut -d'"' -f4)
    if [ -n "$terraform_version" ]; then
        echo -e "${GREEN}✅ Terraform found: v$terraform_version${NC}"
        
        # Validate minimum version (basic check for 1.x)
        if [[ ! "$terraform_version" =~ ^1\. ]]; then
            echo -e "${YELLOW}⚠️ Warning: Terraform version $terraform_version may not be compatible${NC}"
            echo -e "${YELLOW}   Recommended: >= 1.0${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Warning: Could not determine Terraform version${NC}"
    fi
    
    echo -e "${GREEN}✅ Terraform prerequisites validation completed${NC}"
    return 0
}

# Function to validate environment configuration consistency
validate_environment_consistency() {
    local environment=${1:-dev}
    
    # Colors for output
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local RED='\033[0;31m'
    local BLUE='\033[0;34m'
    local NC='\033[0m' # No Color
    
    echo -e "${YELLOW}🔍 Validating environment configuration consistency...${NC}"
    
    local consistency_errors=()
    
    # Check if environment matches the expected value
    if [ "$ENVIRONMENT" != "$environment" ]; then
        consistency_errors+=("ENVIRONMENT variable ($ENVIRONMENT) does not match requested environment ($environment)")
    fi
    
    # Check domain consistency
    if [ "$environment" = "dev" ]; then
        if [[ "$DOMAIN_NAME" != *"dev."* ]] && [ "$DOMAIN_NAME" != "localhost" ]; then
            consistency_errors+=("Development environment should use a dev subdomain or localhost, got '$DOMAIN_NAME'")
        fi
    elif [ "$environment" = "prod" ]; then
        if [[ "$DOMAIN_NAME" == *"dev."* ]] || [[ "$DOMAIN_NAME" == *"localhost"* ]]; then
            consistency_errors+=("Production environment should not use dev subdomain or localhost, got '$DOMAIN_NAME'")
        fi
    fi
    
    # Check S3 bucket prefix consistency
    if [ "$environment" = "dev" ] && [[ "$S3_CONTENT_BUCKET_PREFIX" != *"dev"* ]]; then
        consistency_errors+=("Development S3 bucket prefix should contain 'dev', got '$S3_CONTENT_BUCKET_PREFIX'")
    elif [ "$environment" = "prod" ] && [[ "$S3_CONTENT_BUCKET_PREFIX" != *"prod"* ]]; then
        consistency_errors+=("Production S3 bucket prefix should contain 'prod', got '$S3_CONTENT_BUCKET_PREFIX'")
    fi
    
    # Check CORS origins consistency
    if [ "$environment" = "dev" ]; then
        if [[ "$CORS_ALLOW_ORIGINS" != *"localhost"* ]] && [[ "$CORS_ALLOW_ORIGINS" != *"dev."* ]]; then
            consistency_errors+=("Development CORS origins should include localhost or dev domain")
        fi
    elif [ "$environment" = "prod" ]; then
        if [[ "$CORS_ALLOW_ORIGINS" == *"localhost"* ]] || [[ "$CORS_ALLOW_ORIGINS" == *"dev."* ]]; then
            consistency_errors+=("Production CORS origins should not include localhost or dev domains")
        fi
    fi
    
    # Report consistency validation results
    if [ ${#consistency_errors[@]} -gt 0 ]; then
        echo -e "${RED}❌ Environment configuration consistency errors:${NC}"
        for error in "${consistency_errors[@]}"; do
            echo -e "${RED}  - $error${NC}"
        done
        echo -e "${YELLOW}💡 Please review your config/${environment}.env file${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Environment configuration is consistent${NC}"
    return 0
}

# Function to perform comprehensive validation
perform_comprehensive_validation() {
    local environment=${1:-dev}
    
    # Colors for output
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local RED='\033[0;31m'
    local BLUE='\033[0;34m'
    local NC='\033[0m' # No Color
    
    echo -e "${BLUE}🔍 Performing comprehensive validation for environment: $environment${NC}"
    echo -e "${BLUE}================================================================${NC}"
    
    local validation_failed=false
    
    # Run all validation functions
    if ! validate_environment_variables "$environment"; then
        validation_failed=true
    fi
    
    echo ""
    if ! validate_aws_credentials; then
        validation_failed=true
    fi
    
    echo ""
    if ! validate_terraform_prerequisites; then
        validation_failed=true
    fi
    
    echo ""
    if ! validate_environment_consistency "$environment"; then
        validation_failed=true
    fi
    
    echo -e "${BLUE}================================================================${NC}"
    
    if [ "$validation_failed" = true ]; then
        echo -e "${RED}❌ Comprehensive validation failed${NC}"
        echo -e "${YELLOW}💡 Please fix the above issues before proceeding with deployment${NC}"
        return 1
    fi
    
    echo -e "${GREEN}🎉 Comprehensive validation passed successfully!${NC}"
    echo -e "${GREEN}✅ Environment '$environment' is ready for deployment${NC}"
    return 0
}

# Function to generate terraform.tfvars from environment variables
generate_terraform_tfvars() {
    local target_dir=${1:-.}
    local environment=${2:-$ENVIRONMENT}
    
    # Colors for output
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local NC='\033[0m' # No Color
    
    echo -e "${YELLOW}📝 Generating terraform.tfvars in: $target_dir${NC}"
    
    local tfvars_file="$target_dir/terraform.tfvars"
    
    # Create terraform.tfvars file with environment variables
    cat > "$tfvars_file" << EOF
# Auto-generated terraform.tfvars from environment variables
# Generated on: $(date)
# Environment: $environment

# Project Configuration
project_name = "$PROJECT_NAME"
environment  = "$ENVIRONMENT"
aws_region   = "$AWS_REGION"

# Domain Configuration
domain_name = "$DOMAIN_NAME"
root_domain = "$ROOT_DOMAIN"

# Tags Configuration
cost_center = "$COST_CENTER"
owner       = "$OWNER"

# Cognito Configuration
cognito_min_password_length          = $COGNITO_MIN_PASSWORD_LENGTH
cognito_require_lowercase            = $COGNITO_REQUIRE_LOWERCASE
cognito_require_numbers              = $COGNITO_REQUIRE_NUMBERS
cognito_require_symbols              = $COGNITO_REQUIRE_SYMBOLS
cognito_require_uppercase            = $COGNITO_REQUIRE_UPPERCASE
cognito_temp_password_validity       = $COGNITO_TEMP_PASSWORD_VALIDITY
cognito_mfa_configuration            = "$COGNITO_MFA_CONFIGURATION"
cognito_explicit_auth_flows          = [$(echo "$COGNITO_EXPLICIT_AUTH_FLOWS" | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/"/')]
cognito_allowed_oauth_flows          = [$(echo "$COGNITO_ALLOWED_OAUTH_FLOWS" | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/"/')]
cognito_allowed_oauth_scopes         = [$(echo "$COGNITO_ALLOWED_OAUTH_SCOPES" | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/"/')]
cognito_callback_urls                = [$(echo "$COGNITO_CALLBACK_URLS" | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/"/')]
cognito_logout_urls                  = [$(echo "$COGNITO_LOGOUT_URLS" | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/"/')]
cognito_access_token_validity        = $COGNITO_ACCESS_TOKEN_VALIDITY
cognito_id_token_validity            = $COGNITO_ID_TOKEN_VALIDITY
cognito_refresh_token_validity       = $COGNITO_REFRESH_TOKEN_VALIDITY
cognito_allow_unauthenticated_identities = $COGNITO_ALLOW_UNAUTHENTICATED_IDENTITIES

# S3 Configuration
s3_enable_versioning                     = $S3_ENABLE_VERSIONING
s3_enable_lifecycle_policy               = $S3_ENABLE_LIFECYCLE_POLICY
s3_enable_intelligent_tiering            = $S3_ENABLE_INTELLIGENT_TIERING
s3_enable_object_lock                    = $S3_ENABLE_OBJECT_LOCK
s3_lifecycle_transition_ia_days          = $S3_LIFECYCLE_TRANSITION_IA_DAYS
s3_lifecycle_transition_glacier_days     = $S3_LIFECYCLE_TRANSITION_GLACIER_DAYS
s3_noncurrent_version_expiration_days    = $S3_NONCURRENT_VERSION_EXPIRATION_DAYS
s3_content_bucket_prefix                 = "$S3_CONTENT_BUCKET_PREFIX"
s3_presigned_url_expiration_seconds      = $S3_PRESIGNED_URL_EXPIRATION_SECONDS

# CloudFront Configuration
cloudfront_price_class             = "$CLOUDFRONT_PRICE_CLASS"
cloudfront_enable_ipv6             = $CLOUDFRONT_ENABLE_IPV6
cloudfront_enable_monitoring       = $CLOUDFRONT_ENABLE_MONITORING
cloudfront_content_security_policy = "$CLOUDFRONT_CONTENT_SECURITY_POLICY"
cloudfront_error_caching_min_ttl   = $CLOUDFRONT_ERROR_CACHING_MIN_TTL
cloudfront_logging_include_cookies = $CLOUDFRONT_LOGGING_INCLUDE_COOKIES

# Route53 Configuration
route53_create_hosted_zone             = $ROUTE53_CREATE_HOSTED_ZONE
route53_enable_health_check            = $ROUTE53_ENABLE_HEALTH_CHECK
route53_enable_ipv6                    = $ROUTE53_ENABLE_IPV6
route53_health_check_path              = "$ROUTE53_HEALTH_CHECK_PATH"
route53_health_check_failure_threshold = $ROUTE53_HEALTH_CHECK_FAILURE_THRESHOLD
route53_health_check_request_interval  = $ROUTE53_HEALTH_CHECK_REQUEST_INTERVAL

# CORS Configuration
cors_allow_credentials = $CORS_ALLOW_CREDENTIALS
cors_allow_headers     = [$(echo "$CORS_ALLOW_HEADERS" | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/"/')]
cors_allow_methods     = [$(echo "$CORS_ALLOW_METHODS" | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/"/')]
cors_allow_origins     = [$(echo "$CORS_ALLOW_ORIGINS" | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/"/')]
$(if [ -n "$CORS_EXPOSE_HEADERS" ]; then echo "cors_expose_headers    = [$(echo "$CORS_EXPOSE_HEADERS" | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/"/')]"; fi)
cors_max_age_seconds   = $CORS_MAX_AGE_SECONDS

# Common Tags
common_tags = {
  Project     = "$PROJECT_NAME"
  Environment = "$ENVIRONMENT"
  ManagedBy   = "$MANAGED_BY"
  CreatedBy   = "$CREATED_BY"
  CostCenter  = "$COST_CENTER"
  Owner       = "$OWNER"
}
EOF

    echo -e "${GREEN}✅ terraform.tfvars generated successfully${NC}"
    return 0
}

# Function to export AWS account ID for backend configuration
export_aws_account_id() {
    # Colors for output
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local RED='\033[0;31m'
    local NC='\033[0m' # No Color
    
    echo -e "${YELLOW}🔍 Getting AWS Account ID...${NC}"
    
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ AWS CLI not found${NC}"
        return 1
    fi
    
    local account_id
    account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$account_id" ]; then
        export AWS_ACCOUNT_ID="$account_id"
        echo -e "${GREEN}✅ AWS Account ID: $AWS_ACCOUNT_ID${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to get AWS Account ID${NC}"
        return 1
    fi
}

# Main execution when script is sourced with parameters
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    # Script is being sourced
    if [ $# -gt 0 ]; then
        # Load environment variables first
        if ! load_environment_variables "$1"; then
            echo -e "${RED}❌ Failed to load environment variables${NC}"
            return 1
        fi
        
        # Export AWS account ID
        if ! export_aws_account_id; then
            echo -e "${RED}❌ Failed to export AWS account ID${NC}"
            return 1
        fi
        
        # Perform comprehensive validation
        if ! perform_comprehensive_validation "$1"; then
            echo -e "${RED}❌ Environment validation failed${NC}"
            return 1
        fi
    fi
else
    # Script is being executed directly
    echo "This script should be sourced, not executed directly."
    echo "Usage: source scripts/load-env.sh [environment]"
    exit 1
fi