#!/bin/bash

# Development Deployment Script
# This script mimics the GitHub Actions workflow for local testing

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEV_ENV_DIR="$PROJECT_ROOT/environments/dev"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
COMPONENT="all"
ACTION="plan"
SKIP_VALIDATION=false
SKIP_SECURITY=false

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Local development deployment script for Terraform Next.js infrastructure.

OPTIONS:
    -c, --component COMPONENT   Component to deploy (all, cognito, s3-website, s3-content, cloudfront, route53-acm)
    -a, --action ACTION         Action to perform (plan, apply, destroy)
    --skip-validation          Skip Terraform validation
    --skip-security           Skip security scanning
    -h, --help                Show this help message

EXAMPLES:
    $0                                    # Plan all components
    $0 -c cognito -a apply               # Apply cognito component
    $0 -c all -a plan --skip-security    # Plan all components, skip security scan
    $0 -a destroy                        # Destroy all components

REQUIREMENTS:
    - Terraform >= 1.6.6
    - Terragrunt >= 0.55.1
    - AWS CLI configured with appropriate credentials
    - Checkov (optional, for security scanning)

EOF
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed or not in PATH"
        exit 1
    fi
    
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
    print_status "Terraform version: $TERRAFORM_VERSION"
    
    # Check Terragrunt
    if ! command -v terragrunt &> /dev/null; then
        print_error "Terragrunt is not installed or not in PATH"
        exit 1
    fi
    
    TERRAGRUNT_VERSION=$(terragrunt --version | grep -o 'v[0-9.]*')
    print_status "Terragrunt version: $TERRAGRUNT_VERSION"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed or not in PATH"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured or invalid"
        exit 1
    fi
    
    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=$(aws configure get region || echo "us-east-1")
    print_status "AWS Account: $AWS_ACCOUNT, Region: $AWS_REGION"
    
    # Check Checkov (optional)
    if [ "$SKIP_SECURITY" = false ] && ! command -v checkov &> /dev/null; then
        print_warning "Checkov not found, skipping security scan"
        SKIP_SECURITY=true
    fi
    
    print_success "Prerequisites check completed"
}

# Function to validate Terraform configuration
validate_terraform() {
    if [ "$SKIP_VALIDATION" = true ]; then
        print_warning "Skipping Terraform validation"
        return 0
    fi
    
    print_status "Validating Terraform configuration..."
    
    cd "$PROJECT_ROOT"
    
    # Validate each module
    find modules -name "*.tf" -exec dirname {} \; | sort -u | while read dir; do
        print_status "Validating $dir"
        cd "$dir"
        terraform init -backend=false > /dev/null 2>&1
        if ! terraform validate; then
            print_error "Validation failed for $dir"
            exit 1
        fi
        cd "$PROJECT_ROOT"
    done
    
    # Validate Terragrunt configuration
    cd "$DEV_ENV_DIR"
    if ! terragrunt validate-inputs --terragrunt-non-interactive; then
        print_error "Terragrunt validation failed"
        exit 1
    fi
    
    cd "$PROJECT_ROOT"
    print_success "Terraform validation completed"
}

# Function to run security scan
run_security_scan() {
    if [ "$SKIP_SECURITY" = true ]; then
        print_warning "Skipping security scan"
        return 0
    fi
    
    print_status "Running security scan with Checkov..."
    
    cd "$PROJECT_ROOT"
    
    # Run Checkov scan
    if ! checkov -d . --framework terraform --skip-check CKV_AWS_18,CKV_AWS_19 --quiet; then
        print_warning "Security scan found issues, but continuing..."
    fi
    
    print_success "Security scan completed"
}

# Function to get component list
get_components() {
    if [ "$COMPONENT" = "all" ]; then
        echo "cognito s3-website s3-content route53-acm cloudfront"
    else
        echo "$COMPONENT"
    fi
}

# Function to plan components
plan_components() {
    print_status "Planning components: $(get_components)"
    
    cd "$DEV_ENV_DIR"
    
    local components=$(get_components)
    local has_changes=false
    
    for component in $components; do
        if [ -d "$component" ]; then
            print_status "Planning $component..."
            cd "$component"
            
            # Initialize
            if ! terragrunt init --terragrunt-non-interactive; then
                print_error "Failed to initialize $component"
                exit 1
            fi
            
            # Plan
            if terragrunt plan -detailed-exitcode --terragrunt-non-interactive; then
                print_success "No changes for $component"
            else
                local exitcode=$?
                if [ $exitcode -eq 2 ]; then
                    print_warning "Changes detected for $component"
                    has_changes=true
                else
                    print_error "Planning failed for $component"
                    exit 1
                fi
            fi
            
            cd "$DEV_ENV_DIR"
        else
            print_warning "Component $component not found, skipping..."
        fi
    done
    
    if [ "$has_changes" = true ]; then
        print_warning "Changes detected in one or more components"
        return 2
    else
        print_success "No changes detected in any component"
        return 0
    fi
}

# Function to apply components
apply_components() {
    print_status "Applying components: $(get_components)"
    
    cd "$DEV_ENV_DIR"
    
    local components=$(get_components)
    
    for component in $components; do
        if [ -d "$component" ]; then
            print_status "Applying $component..."
            cd "$component"
            
            if ! terragrunt apply --terragrunt-non-interactive -auto-approve; then
                print_error "Failed to apply $component"
                exit 1
            fi
            
            print_success "Successfully applied $component"
            cd "$DEV_ENV_DIR"
        else
            print_warning "Component $component not found, skipping..."
        fi
    done
    
    print_success "All components applied successfully"
}

# Function to destroy components
destroy_components() {
    print_warning "Destroying components: $(get_components)"
    
    # Confirm destruction
    read -p "Are you sure you want to destroy the selected components? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_status "Destruction cancelled"
        exit 0
    fi
    
    cd "$DEV_ENV_DIR"
    
    # Destroy in reverse order
    local components
    if [ "$COMPONENT" = "all" ]; then
        components="cloudfront route53-acm s3-content s3-website cognito"
    else
        components="$COMPONENT"
    fi
    
    for component in $components; do
        if [ -d "$component" ]; then
            print_status "Destroying $component..."
            cd "$component"
            
            if ! terragrunt destroy --terragrunt-non-interactive -auto-approve; then
                print_warning "Failed to destroy $component, continuing..."
            else
                print_success "Successfully destroyed $component"
            fi
            
            cd "$DEV_ENV_DIR"
        else
            print_warning "Component $component not found, skipping..."
        fi
    done
    
    print_success "Destruction completed"
}

# Function to verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    cd "$DEV_ENV_DIR"
    
    local components=$(get_components)
    
    for component in $components; do
        if [ -d "$component" ]; then
            print_status "Verifying $component outputs..."
            cd "$component"
            terragrunt output --terragrunt-non-interactive || print_warning "No outputs for $component"
            cd "$DEV_ENV_DIR"
        fi
    done
    
    print_success "Deployment verification completed"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--component)
            COMPONENT="$2"
            shift 2
            ;;
        -a|--action)
            ACTION="$2"
            shift 2
            ;;
        --skip-validation)
            SKIP_VALIDATION=true
            shift
            ;;
        --skip-security)
            SKIP_SECURITY=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate arguments
case $COMPONENT in
    all|cognito|s3-website|s3-content|cloudfront|route53-acm)
        ;;
    *)
        print_error "Invalid component: $COMPONENT"
        show_usage
        exit 1
        ;;
esac

case $ACTION in
    plan|apply|destroy)
        ;;
    *)
        print_error "Invalid action: $ACTION"
        show_usage
        exit 1
        ;;
esac

# Main execution
main() {
    print_status "Starting development deployment script"
    print_status "Component: $COMPONENT, Action: $ACTION"
    
    # Check prerequisites
    check_prerequisites
    
    # Validate configuration
    validate_terraform
    
    # Run security scan
    run_security_scan
    
    # Execute action
    case $ACTION in
        plan)
            plan_components
            ;;
        apply)
            plan_components
            apply_components
            verify_deployment
            ;;
        destroy)
            destroy_components
            ;;
    esac
    
    print_success "Development deployment script completed successfully!"
}

# Run main function
main