#!/bin/bash

# Environment Cleanup and Resource Management Script
# This script provides utilities for cleaning up and managing AWS resources

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_ENVIRONMENT="dev"

# Help function
show_help() {
    cat << EOF
Environment Cleanup and Resource Management Script

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    destroy     Destroy all resources in an environment
    cleanup     Clean up specific resource types
    list        List all resources in an environment
    validate    Validate resource state and configuration
    backup      Backup important data before cleanup
    help        Show this help message

OPTIONS:
    -e, --environment ENV   Environment to manage (dev/prod) [default: $DEFAULT_ENVIRONMENT]
    -r, --resource TYPE     Resource type to manage (s3/cognito/cloudfront/all)
    -f, --force            Force operation without confirmation
    -b, --backup           Create backup before cleanup
    -d, --dry-run          Show what would be done without executing
    -v, --verbose          Verbose output

EXAMPLES:
    # List all resources in dev environment
    $0 list -e dev
    
    # Clean up S3 buckets in dev environment with backup
    $0 cleanup -e dev -r s3 -b
    
    # Destroy entire dev environment (with confirmation)
    $0 destroy -e dev
    
    # Dry run of production cleanup
    $0 cleanup -e prod -r all --dry-run
    
    # Validate resource state
    $0 validate -e dev -v

EOF
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are available
check_dependencies() {
    local missing_tools=()
    
    if ! command -v aws &> /dev/null; then
        missing_tools+=("aws")
    fi
    
    if ! command -v terragrunt &> /dev/null; then
        missing_tools+=("terragrunt")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and try again"
        return 1
    fi
    
    # Check AWS CLI configuration
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI is not configured or credentials are invalid"
        log_info "Run 'aws configure' to set up your credentials"
        return 1
    fi
    
    log_info "All dependencies are available"
    return 0
}

# Confirm dangerous operations
confirm_operation() {
    local operation=$1
    local environment=$2
    local force=$3
    
    if [ "$force" = "true" ]; then
        return 0
    fi
    
    echo ""
    log_warning "You are about to $operation in the '$environment' environment"
    log_warning "This operation may be irreversible!"
    echo ""
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirmation
    
    if [ "$confirmation" != "yes" ]; then
        log_info "Operation cancelled by user"
        return 1
    fi
    
    return 0
}

# Get environment path
get_environment_path() {
    local environment=$1
    local env_path="$PROJECT_ROOT/environments/$environment"
    
    if [ ! -d "$env_path" ]; then
        log_error "Environment directory not found: $env_path"
        return 1
    fi
    
    echo "$env_path"
}

# List resources in environment
list_resources() {
    local environment=$1
    local verbose=$2
    
    log_info "Listing resources in '$environment' environment..."
    
    local env_path
    env_path=$(get_environment_path "$environment")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    echo ""
    echo "Environment: $environment"
    echo "========================="
    
    # List Terragrunt modules
    local modules=()
    for module_dir in "$env_path"/*; do
        if [ -d "$module_dir" ] && [ -f "$module_dir/terragrunt.hcl" ]; then
            modules+=($(basename "$module_dir"))
        fi
    done
    
    if [ ${#modules[@]} -eq 0 ]; then
        log_warning "No Terragrunt modules found in environment"
        return 0
    fi
    
    echo "Terragrunt Modules:"
    echo "------------------"
    for module in "${modules[@]}"; do
        echo "  - $module"
        
        if [ "$verbose" = "true" ]; then
            # Get module outputs if available
            cd "$env_path/$module"
            local outputs
            outputs=$(terragrunt output -json 2>/dev/null || echo "{}")
            
            if [ "$outputs" != "{}" ] && command -v jq &> /dev/null; then
                echo "$outputs" | jq -r 'to_entries[] | "    \(.key): \(.value.value)"' 2>/dev/null || true
            fi
            cd - > /dev/null
        fi
    done
    
    echo ""
    
    # List AWS resources if verbose
    if [ "$verbose" = "true" ]; then
        log_info "Checking AWS resources..."
        
        # S3 buckets
        local buckets
        buckets=$(aws s3api list-buckets --query "Buckets[?contains(Name, '$environment')].Name" --output text 2>/dev/null || echo "")
        if [ -n "$buckets" ]; then
            echo "S3 Buckets:"
            echo "----------"
            for bucket in $buckets; do
                echo "  - $bucket"
            done
            echo ""
        fi
        
        # Cognito User Pools
        local user_pools
        user_pools=$(aws cognito-idp list-user-pools --max-results 60 --query "UserPools[?contains(Name, '$environment')].Name" --output text 2>/dev/null || echo "")
        if [ -n "$user_pools" ]; then
            echo "Cognito User Pools:"
            echo "------------------"
            for pool in $user_pools; do
                echo "  - $pool"
            done
            echo ""
        fi
        
        # CloudFront Distributions
        local distributions
        distributions=$(aws cloudfront list-distributions --query "DistributionList.Items[?contains(Comment, '$environment')].Id" --output text 2>/dev/null || echo "")
        if [ -n "$distributions" ]; then
            echo "CloudFront Distributions:"
            echo "------------------------"
            for dist in $distributions; do
                echo "  - $dist"
            done
            echo ""
        fi
    fi
}

# Validate resource state
validate_resources() {
    local environment=$1
    local verbose=$2
    
    log_info "Validating resources in '$environment' environment..."
    
    local env_path
    env_path=$(get_environment_path "$environment")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    local validation_errors=0
    
    # Validate each Terragrunt module
    for module_dir in "$env_path"/*; do
        if [ -d "$module_dir" ] && [ -f "$module_dir/terragrunt.hcl" ]; then
            local module_name
            module_name=$(basename "$module_dir")
            
            log_info "Validating module: $module_name"
            
            cd "$module_dir"
            
            # Run terragrunt validate
            if ! terragrunt validate &> /dev/null; then
                log_error "Validation failed for module: $module_name"
                validation_errors=$((validation_errors + 1))
                
                if [ "$verbose" = "true" ]; then
                    terragrunt validate
                fi
            else
                log_success "Module $module_name is valid"
            fi
            
            # Check if state exists and is accessible
            if ! terragrunt state list &> /dev/null; then
                log_warning "State not accessible for module: $module_name"
            fi
            
            cd - > /dev/null
        fi
    done
    
    if [ $validation_errors -eq 0 ]; then
        log_success "All modules passed validation"
    else
        log_error "Found $validation_errors validation errors"
        return 1
    fi
}

# Backup important data
backup_data() {
    local environment=$1
    local verbose=$2
    
    log_info "Creating backup for '$environment' environment..."
    
    local backup_dir="$PROJECT_ROOT/backups/$environment-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup Terraform state files
    log_info "Backing up Terraform state files..."
    local env_path
    env_path=$(get_environment_path "$environment")
    
    for module_dir in "$env_path"/*; do
        if [ -d "$module_dir" ] && [ -f "$module_dir/terragrunt.hcl" ]; then
            local module_name
            module_name=$(basename "$module_dir")
            
            cd "$module_dir"
            
            # Pull latest state
            if terragrunt state pull > "$backup_dir/$module_name-terraform.tfstate" 2>/dev/null; then
                log_success "Backed up state for module: $module_name"
            else
                log_warning "Could not backup state for module: $module_name"
            fi
            
            cd - > /dev/null
        fi
    done
    
    # Backup S3 bucket contents (metadata only)
    log_info "Backing up S3 bucket metadata..."
    local buckets
    buckets=$(aws s3api list-buckets --query "Buckets[?contains(Name, '$environment')].Name" --output text 2>/dev/null || echo "")
    
    for bucket in $buckets; do
        if [ -n "$bucket" ]; then
            aws s3api list-objects-v2 --bucket "$bucket" > "$backup_dir/$bucket-objects.json" 2>/dev/null || true
            log_info "Backed up metadata for bucket: $bucket"
        fi
    done
    
    # Create backup manifest
    cat > "$backup_dir/manifest.txt" << EOF
Backup created: $(date)
Environment: $environment
Backup directory: $backup_dir

Contents:
- Terraform state files (*.tfstate)
- S3 bucket metadata (*-objects.json)

To restore:
1. Copy state files to appropriate module directories
2. Run 'terragrunt state push <state-file>' in each module
3. Verify with 'terragrunt plan'
EOF
    
    log_success "Backup completed: $backup_dir"
    
    if [ "$verbose" = "true" ]; then
        echo ""
        echo "Backup contents:"
        ls -la "$backup_dir"
    fi
}

# Clean up specific resource types
cleanup_resources() {
    local environment=$1
    local resource_type=$2
    local force=$3
    local backup=$4
    local dry_run=$5
    local verbose=$6
    
    if [ "$backup" = "true" ]; then
        backup_data "$environment" "$verbose"
    fi
    
    if ! confirm_operation "clean up $resource_type resources" "$environment" "$force"; then
        return 1
    fi
    
    local env_path
    env_path=$(get_environment_path "$environment")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    case $resource_type in
        "s3")
            cleanup_s3_resources "$environment" "$dry_run" "$verbose"
            ;;
        "cognito")
            cleanup_cognito_resources "$environment" "$dry_run" "$verbose"
            ;;
        "cloudfront")
            cleanup_cloudfront_resources "$environment" "$dry_run" "$verbose"
            ;;
        "all")
            cleanup_all_resources "$environment" "$dry_run" "$verbose"
            ;;
        *)
            log_error "Unknown resource type: $resource_type"
            log_info "Supported types: s3, cognito, cloudfront, all"
            return 1
            ;;
    esac
}

# Clean up S3 resources
cleanup_s3_resources() {
    local environment=$1
    local dry_run=$2
    local verbose=$3
    
    log_info "Cleaning up S3 resources for '$environment' environment..."
    
    # Find S3 modules
    local env_path
    env_path=$(get_environment_path "$environment")
    
    for module_type in "s3-website" "s3-content"; do
        local module_path="$env_path/$module_type"
        
        if [ -d "$module_path" ]; then
            log_info "Processing module: $module_type"
            
            if [ "$dry_run" = "true" ]; then
                log_info "[DRY RUN] Would destroy module: $module_type"
            else
                cd "$module_path"
                
                # Empty S3 buckets first
                local bucket_name
                bucket_name=$(terragrunt output -raw bucket_name 2>/dev/null || echo "")
                
                if [ -n "$bucket_name" ]; then
                    log_info "Emptying S3 bucket: $bucket_name"
                    aws s3 rm "s3://$bucket_name" --recursive 2>/dev/null || true
                fi
                
                # Destroy the module
                if terragrunt destroy -auto-approve; then
                    log_success "Destroyed module: $module_type"
                else
                    log_error "Failed to destroy module: $module_type"
                fi
                
                cd - > /dev/null
            fi
        fi
    done
}

# Clean up Cognito resources
cleanup_cognito_resources() {
    local environment=$1
    local dry_run=$2
    local verbose=$3
    
    log_info "Cleaning up Cognito resources for '$environment' environment..."
    
    local env_path
    env_path=$(get_environment_path "$environment")
    local module_path="$env_path/cognito"
    
    if [ -d "$module_path" ]; then
        if [ "$dry_run" = "true" ]; then
            log_info "[DRY RUN] Would destroy Cognito module"
        else
            cd "$module_path"
            
            if terragrunt destroy -auto-approve; then
                log_success "Destroyed Cognito module"
            else
                log_error "Failed to destroy Cognito module"
            fi
            
            cd - > /dev/null
        fi
    else
        log_warning "Cognito module not found"
    fi
}

# Clean up CloudFront resources
cleanup_cloudfront_resources() {
    local environment=$1
    local dry_run=$2
    local verbose=$3
    
    log_info "Cleaning up CloudFront resources for '$environment' environment..."
    
    local env_path
    env_path=$(get_environment_path "$environment")
    local module_path="$env_path/cloudfront"
    
    if [ -d "$module_path" ]; then
        if [ "$dry_run" = "true" ]; then
            log_info "[DRY RUN] Would destroy CloudFront module"
        else
            cd "$module_path"
            
            if terragrunt destroy -auto-approve; then
                log_success "Destroyed CloudFront module"
            else
                log_error "Failed to destroy CloudFront module"
            fi
            
            cd - > /dev/null
        fi
    else
        log_warning "CloudFront module not found"
    fi
}

# Clean up all resources
cleanup_all_resources() {
    local environment=$1
    local dry_run=$2
    local verbose=$3
    
    log_info "Cleaning up ALL resources for '$environment' environment..."
    
    # Destroy in reverse dependency order
    cleanup_cloudfront_resources "$environment" "$dry_run" "$verbose"
    cleanup_s3_resources "$environment" "$dry_run" "$verbose"
    cleanup_cognito_resources "$environment" "$dry_run" "$verbose"
}

# Destroy entire environment
destroy_environment() {
    local environment=$1
    local force=$2
    local backup=$3
    local dry_run=$4
    local verbose=$5
    
    if [ "$backup" = "true" ]; then
        backup_data "$environment" "$verbose"
    fi
    
    if ! confirm_operation "DESTROY the entire '$environment' environment" "$environment" "$force"; then
        return 1
    fi
    
    local env_path
    env_path=$(get_environment_path "$environment")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    if [ "$dry_run" = "true" ]; then
        log_info "[DRY RUN] Would destroy entire '$environment' environment"
        list_resources "$environment" true
        return 0
    fi
    
    log_info "Destroying entire '$environment' environment..."
    
    # Use terragrunt run-all destroy for proper dependency handling
    cd "$env_path"
    
    if terragrunt run-all destroy -auto-approve; then
        log_success "Successfully destroyed '$environment' environment"
    else
        log_error "Failed to destroy '$environment' environment"
        log_info "Some resources may still exist. Check manually and retry if needed."
        return 1
    fi
    
    cd - > /dev/null
}

# Main function
main() {
    local command=""
    local environment="$DEFAULT_ENVIRONMENT"
    local resource_type="all"
    local force="false"
    local backup="false"
    local dry_run="false"
    local verbose="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            destroy|cleanup|list|validate|backup|help)
                command="$1"
                shift
                ;;
            -e|--environment)
                environment="$2"
                shift 2
                ;;
            -r|--resource)
                resource_type="$2"
                shift 2
                ;;
            -f|--force)
                force="true"
                shift
                ;;
            -b|--backup)
                backup="true"
                shift
                ;;
            -d|--dry-run)
                dry_run="true"
                shift
                ;;
            -v|--verbose)
                verbose="true"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Show help if no command provided
    if [ -z "$command" ]; then
        show_help
        exit 0
    fi
    
    # Check dependencies
    if ! check_dependencies; then
        exit 1
    fi
    
    # Execute command
    case $command in
        destroy)
            destroy_environment "$environment" "$force" "$backup" "$dry_run" "$verbose"
            ;;
        cleanup)
            cleanup_resources "$environment" "$resource_type" "$force" "$backup" "$dry_run" "$verbose"
            ;;
        list)
            list_resources "$environment" "$verbose"
            ;;
        validate)
            validate_resources "$environment" "$verbose"
            ;;
        backup)
            backup_data "$environment" "$verbose"
            ;;
        help)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"