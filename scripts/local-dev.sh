#!/bin/bash

# Local Development and Testing Script
# This script provides utilities for local development and testing of the infrastructure

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
Local Development and Testing Script

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    setup       Set up local development environment
    plan        Run Terragrunt plan for modules
    apply       Apply Terragrunt changes
    test        Run infrastructure tests
    validate    Validate Terraform configuration
    format      Format Terraform files
    docs        Generate documentation
    clean       Clean up temporary files
    help        Show this help message

OPTIONS:
    -e, --environment ENV   Environment to work with (dev/prod) [default: $DEFAULT_ENVIRONMENT]
    -m, --module MODULE     Specific module to work with
    -t, --test-type TYPE    Test type (unit/integration/smoke/all) [default: all]
    -f, --fix              Auto-fix issues where possible
    -v, --verbose          Verbose output

EXAMPLES:
    # Set up local development environment
    $0 setup
    
    # Plan changes for dev environment
    $0 plan -e dev
    
    # Apply changes to specific module
    $0 apply -e dev -m s3-website
    
    # Run all tests
    $0 test -e dev
    
    # Run only smoke tests
    $0 test -e dev -t smoke
    
    # Validate and format code
    $0 validate -f
    $0 format

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
    
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    if ! command -v terragrunt &> /dev/null; then
        missing_tools+=("terragrunt")
    fi
    
    if ! command -v aws &> /dev/null; then
        missing_tools+=("aws")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and try again"
        return 1
    fi
    
    log_info "All required tools are available"
    return 0
}

# Set up local development environment
setup_dev_environment() {
    local verbose=$1
    
    log_info "Setting up local development environment..."
    
    # Check dependencies
    if ! check_dependencies; then
        return 1
    fi
    
    # Check AWS CLI configuration
    if ! aws sts get-caller-identity &> /dev/null; then
        log_warning "AWS CLI is not configured"
        log_info "Run 'aws configure' to set up your credentials"
        log_info "You can continue with validation and formatting without AWS credentials"
    else
        log_success "AWS CLI is configured"
    fi
    
    # Initialize Terraform modules
    log_info "Initializing Terraform modules..."
    
    for module_dir in "$PROJECT_ROOT/modules"/*; do
        if [ -d "$module_dir" ] && [ -f "$module_dir/main.tf" ]; then
            local module_name
            module_name=$(basename "$module_dir")
            
            log_info "Initializing module: $module_name"
            
            cd "$module_dir"
            if terraform init -backend=false &> /dev/null; then
                log_success "Initialized module: $module_name"
            else
                log_warning "Failed to initialize module: $module_name"
            fi
            cd - > /dev/null
        fi
    done
    
    # Set up pre-commit hooks if available
    if command -v pre-commit &> /dev/null; then
        log_info "Setting up pre-commit hooks..."
        if [ -f "$PROJECT_ROOT/.pre-commit-config.yaml" ]; then
            cd "$PROJECT_ROOT"
            pre-commit install
            log_success "Pre-commit hooks installed"
            cd - > /dev/null
        else
            log_info "No pre-commit configuration found"
        fi
    fi
    
    # Create local directories
    mkdir -p "$PROJECT_ROOT/logs"
    mkdir -p "$PROJECT_ROOT/tmp"
    
    log_success "Local development environment setup complete!"
    
    if [ "$verbose" = "true" ]; then
        echo ""
        echo "Next steps:"
        echo "1. Configure AWS credentials: aws configure"
        echo "2. Plan infrastructure: $0 plan -e dev"
        echo "3. Apply infrastructure: $0 apply -e dev"
        echo "4. Run tests: $0 test -e dev"
    fi
}

# Run Terragrunt plan
run_plan() {
    local environment=$1
    local module=$2
    local verbose=$3
    
    log_info "Running Terragrunt plan for '$environment' environment..."
    
    local env_path="$PROJECT_ROOT/environments/$environment"
    
    if [ ! -d "$env_path" ]; then
        log_error "Environment directory not found: $env_path"
        return 1
    fi
    
    if [ -n "$module" ]; then
        # Plan specific module
        local module_path="$env_path/$module"
        
        if [ ! -d "$module_path" ]; then
            log_error "Module directory not found: $module_path"
            return 1
        fi
        
        log_info "Planning module: $module"
        
        cd "$module_path"
        if terragrunt plan; then
            log_success "Plan completed for module: $module"
        else
            log_error "Plan failed for module: $module"
            return 1
        fi
        cd - > /dev/null
    else
        # Plan all modules
        log_info "Planning all modules in environment: $environment"
        
        cd "$env_path"
        if terragrunt run-all plan; then
            log_success "Plan completed for all modules"
        else
            log_error "Plan failed for one or more modules"
            return 1
        fi
        cd - > /dev/null
    fi
}

# Apply Terragrunt changes
run_apply() {
    local environment=$1
    local module=$2
    local verbose=$3
    
    log_info "Applying Terragrunt changes for '$environment' environment..."
    
    local env_path="$PROJECT_ROOT/environments/$environment"
    
    if [ ! -d "$env_path" ]; then
        log_error "Environment directory not found: $env_path"
        return 1
    fi
    
    # Confirmation for apply
    echo ""
    log_warning "You are about to apply changes to the '$environment' environment"
    if [ -n "$module" ]; then
        log_warning "Module: $module"
    else
        log_warning "All modules will be affected"
    fi
    echo ""
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirmation
    
    if [ "$confirmation" != "yes" ]; then
        log_info "Apply cancelled by user"
        return 0
    fi
    
    if [ -n "$module" ]; then
        # Apply specific module
        local module_path="$env_path/$module"
        
        if [ ! -d "$module_path" ]; then
            log_error "Module directory not found: $module_path"
            return 1
        fi
        
        log_info "Applying module: $module"
        
        cd "$module_path"
        if terragrunt apply; then
            log_success "Apply completed for module: $module"
        else
            log_error "Apply failed for module: $module"
            return 1
        fi
        cd - > /dev/null
    else
        # Apply all modules
        log_info "Applying all modules in environment: $environment"
        
        cd "$env_path"
        if terragrunt run-all apply; then
            log_success "Apply completed for all modules"
        else
            log_error "Apply failed for one or more modules"
            return 1
        fi
        cd - > /dev/null
    fi
}

# Run infrastructure tests
run_tests() {
    local environment=$1
    local test_type=$2
    local verbose=$3
    
    log_info "Running infrastructure tests..."
    
    local test_dir="$PROJECT_ROOT/test"
    
    if [ ! -d "$test_dir" ]; then
        log_error "Test directory not found: $test_dir"
        return 1
    fi
    
    cd "$test_dir"
    
    case $test_type in
        "unit")
            log_info "Running unit tests..."
            if make test-modules; then
                log_success "Unit tests passed"
            else
                log_error "Unit tests failed"
                return 1
            fi
            ;;
        "integration")
            log_info "Running integration tests..."
            if make test-integration ENV="$environment"; then
                log_success "Integration tests passed"
            else
                log_error "Integration tests failed"
                return 1
            fi
            ;;
        "smoke")
            log_info "Running smoke tests..."
            if make test-smoke ENV="$environment"; then
                log_success "Smoke tests passed"
            else
                log_error "Smoke tests failed"
                return 1
            fi
            ;;
        "all"|*)
            log_info "Running all tests..."
            
            # Run tests in order
            local test_types=("unit" "integration" "smoke")
            for type in "${test_types[@]}"; do
                log_info "Running $type tests..."
                
                case $type in
                    "unit")
                        make test-modules
                        ;;
                    "integration")
                        make test-integration ENV="$environment"
                        ;;
                    "smoke")
                        make test-smoke ENV="$environment"
                        ;;
                esac
                
                if [ $? -eq 0 ]; then
                    log_success "$type tests passed"
                else
                    log_error "$type tests failed"
                    return 1
                fi
            done
            ;;
    esac
    
    cd - > /dev/null
    log_success "All tests completed successfully"
}

# Validate Terraform configuration
validate_terraform() {
    local fix=$1
    local verbose=$2
    
    log_info "Validating Terraform configuration..."
    
    local validation_errors=0
    
    # Validate modules
    for module_dir in "$PROJECT_ROOT/modules"/*; do
        if [ -d "$module_dir" ] && [ -f "$module_dir/main.tf" ]; then
            local module_name
            module_name=$(basename "$module_dir")
            
            log_info "Validating module: $module_name"
            
            cd "$module_dir"
            
            # Initialize if needed
            if [ ! -d ".terraform" ]; then
                terraform init -backend=false &> /dev/null
            fi
            
            # Validate
            if terraform validate; then
                log_success "Module $module_name is valid"
            else
                log_error "Validation failed for module: $module_name"
                validation_errors=$((validation_errors + 1))
            fi
            
            cd - > /dev/null
        fi
    done
    
    # Validate environments
    for env_dir in "$PROJECT_ROOT/environments"/*; do
        if [ -d "$env_dir" ]; then
            local env_name
            env_name=$(basename "$env_dir")
            
            log_info "Validating environment: $env_name"
            
            for module_dir in "$env_dir"/*; do
                if [ -d "$module_dir" ] && [ -f "$module_dir/terragrunt.hcl" ]; then
                    local module_name
                    module_name=$(basename "$module_dir")
                    
                    cd "$module_dir"
                    
                    if terragrunt validate &> /dev/null; then
                        if [ "$verbose" = "true" ]; then
                            log_success "Environment $env_name/$module_name is valid"
                        fi
                    else
                        log_error "Validation failed for environment: $env_name/$module_name"
                        validation_errors=$((validation_errors + 1))
                        
                        if [ "$verbose" = "true" ]; then
                            terragrunt validate
                        fi
                    fi
                    
                    cd - > /dev/null
                fi
            done
        fi
    done
    
    if [ $validation_errors -eq 0 ]; then
        log_success "All configurations are valid"
    else
        log_error "Found $validation_errors validation errors"
        return 1
    fi
}

# Format Terraform files
format_terraform() {
    local fix=$1
    local verbose=$2
    
    log_info "Formatting Terraform files..."
    
    # Format modules
    for module_dir in "$PROJECT_ROOT/modules"/*; do
        if [ -d "$module_dir" ] && [ -f "$module_dir/main.tf" ]; then
            local module_name
            module_name=$(basename "$module_dir")
            
            cd "$module_dir"
            
            if [ "$fix" = "true" ]; then
                terraform fmt -recursive
                log_info "Formatted module: $module_name"
            else
                if terraform fmt -check -recursive; then
                    if [ "$verbose" = "true" ]; then
                        log_success "Module $module_name is properly formatted"
                    fi
                else
                    log_warning "Module $module_name needs formatting"
                fi
            fi
            
            cd - > /dev/null
        fi
    done
    
    # Format root files
    cd "$PROJECT_ROOT"
    
    if [ "$fix" = "true" ]; then
        terraform fmt -recursive
        log_info "Formatted root directory"
    else
        if terraform fmt -check -recursive; then
            if [ "$verbose" = "true" ]; then
                log_success "Root directory is properly formatted"
            fi
        else
            log_warning "Root directory needs formatting"
        fi
    fi
    
    cd - > /dev/null
    
    if [ "$fix" = "true" ]; then
        log_success "All files have been formatted"
    else
        log_success "Format check completed"
    fi
}

# Generate documentation
generate_docs() {
    local verbose=$1
    
    log_info "Generating documentation..."
    
    # Generate module documentation
    for module_dir in "$PROJECT_ROOT/modules"/*; do
        if [ -d "$module_dir" ] && [ -f "$module_dir/main.tf" ]; then
            local module_name
            module_name=$(basename "$module_dir")
            
            log_info "Generating docs for module: $module_name"
            
            cd "$module_dir"
            
            # Use terraform-docs if available
            if command -v terraform-docs &> /dev/null; then
                terraform-docs markdown table --output-file README.md .
                log_success "Generated docs for module: $module_name"
            else
                log_warning "terraform-docs not available, skipping module: $module_name"
            fi
            
            cd - > /dev/null
        fi
    done
    
    log_success "Documentation generation completed"
}

# Clean up temporary files
clean_temp_files() {
    local verbose=$1
    
    log_info "Cleaning up temporary files..."
    
    # Clean Terraform files
    find "$PROJECT_ROOT" -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
    find "$PROJECT_ROOT" -name "*.tfplan" -type f -delete 2>/dev/null || true
    find "$PROJECT_ROOT" -name ".terragrunt-cache" -type d -exec rm -rf {} + 2>/dev/null || true
    
    # Clean log files
    rm -rf "$PROJECT_ROOT/logs"/* 2>/dev/null || true
    rm -rf "$PROJECT_ROOT/tmp"/* 2>/dev/null || true
    
    log_success "Temporary files cleaned up"
}

# Main function
main() {
    local command=""
    local environment="$DEFAULT_ENVIRONMENT"
    local module=""
    local test_type="all"
    local fix="false"
    local verbose="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            setup|plan|apply|test|validate|format|docs|clean|help)
                command="$1"
                shift
                ;;
            -e|--environment)
                environment="$2"
                shift 2
                ;;
            -m|--module)
                module="$2"
                shift 2
                ;;
            -t|--test-type)
                test_type="$2"
                shift 2
                ;;
            -f|--fix)
                fix="true"
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
    
    # Execute command
    case $command in
        setup)
            setup_dev_environment "$verbose"
            ;;
        plan)
            run_plan "$environment" "$module" "$verbose"
            ;;
        apply)
            run_apply "$environment" "$module" "$verbose"
            ;;
        test)
            run_tests "$environment" "$test_type" "$verbose"
            ;;
        validate)
            validate_terraform "$fix" "$verbose"
            ;;
        format)
            format_terraform "$fix" "$verbose"
            ;;
        docs)
            generate_docs "$verbose"
            ;;
        clean)
            clean_temp_files "$verbose"
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