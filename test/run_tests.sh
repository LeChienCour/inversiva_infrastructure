#!/bin/bash

# Terraform Next.js Infrastructure Test Runner
# This script provides a convenient way to run different test suites

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
AWS_REGION=${AWS_REGION:-"us-east-1"}
TEST_ENVIRONMENT=${TEST_ENVIRONMENT:-"test"}
CLEANUP_RESOURCES=${CLEANUP_RESOURCES:-"true"}
TEST_TIMEOUT=${TEST_TIMEOUT:-"30m"}
PARALLEL=${PARALLEL:-"2"}

# Function to print colored output
print_info() {
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

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check Go installation
    if ! command -v go &> /dev/null; then
        print_error "Go is not installed. Please install Go 1.21 or later."
        exit 1
    fi
    
    # Check Go version
    GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
    if [[ $(echo "$GO_VERSION 1.21" | tr " " "\n" | sort -V | head -n1) != "1.21" ]]; then
        print_error "Go version 1.21 or later is required. Current version: $GO_VERSION"
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed."
        exit 1
    fi
    
    # Check Terragrunt
    if ! command -v terragrunt &> /dev/null; then
        print_error "Terragrunt is not installed."
        exit 1
    fi
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured or invalid."
        print_info "Please run 'aws configure' to set up your credentials."
        exit 1
    fi
    
    print_success "All prerequisites are met."
}

# Function to install Go dependencies
install_dependencies() {
    print_info "Installing Go dependencies..."
    go mod download
    go mod tidy
    print_success "Dependencies installed."
}

# Function to run specific test suite
run_test_suite() {
    local suite=$1
    local description=$2
    
    print_info "Running $description..."
    
    export AWS_REGION
    export TEST_ENVIRONMENT
    export CLEANUP_RESOURCES
    
    if go test -v -timeout "$TEST_TIMEOUT" -parallel "$PARALLEL" "./$suite/..."; then
        print_success "$description completed successfully."
        return 0
    else
        print_error "$description failed."
        return 1
    fi
}

# Function to run all tests
run_all_tests() {
    print_info "Running all test suites..."
    
    local failed_suites=()
    
    # Run each test suite
    if ! run_test_suite "modules" "Module unit tests"; then
        failed_suites+=("modules")
    fi
    
    if ! run_test_suite "integration" "Integration tests"; then
        failed_suites+=("integration")
    fi
    
    if ! run_test_suite "smoke" "Smoke tests"; then
        failed_suites+=("smoke")
    fi
    
    if ! run_test_suite "security" "Security tests"; then
        failed_suites+=("security")
    fi
    
    if ! run_test_suite "cost" "Cost optimization tests"; then
        failed_suites+=("cost")
    fi
    
    # Report results
    if [ ${#failed_suites[@]} -eq 0 ]; then
        print_success "All test suites passed!"
        return 0
    else
        print_error "The following test suites failed: ${failed_suites[*]}"
        return 1
    fi
}

# Function to run quick tests
run_quick_tests() {
    print_info "Running quick tests (short mode)..."
    
    export AWS_REGION
    export TEST_ENVIRONMENT
    export CLEANUP_RESOURCES
    
    if go test -v -short -timeout "10m" -parallel "$PARALLEL" "./modules/..."; then
        print_success "Quick tests completed successfully."
        return 0
    else
        print_error "Quick tests failed."
        return 1
    fi
}

# Function to run specific test
run_specific_test() {
    local test_name=$1
    
    if [ -z "$test_name" ]; then
        print_error "Test name is required for specific test execution."
        print_info "Usage: $0 specific <TestName>"
        exit 1
    fi
    
    print_info "Running specific test: $test_name"
    
    export AWS_REGION
    export TEST_ENVIRONMENT
    export CLEANUP_RESOURCES
    
    if go test -v -timeout "$TEST_TIMEOUT" -run "$test_name" "./..."; then
        print_success "Test $test_name completed successfully."
        return 0
    else
        print_error "Test $test_name failed."
        return 1
    fi
}

# Function to clean up test artifacts
cleanup() {
    print_info "Cleaning up test artifacts..."
    go clean -testcache
    find . -name "*.tfstate*" -delete 2>/dev/null || true
    find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
    find . -name ".terraform.lock.hcl" -delete 2>/dev/null || true
    print_success "Cleanup completed."
}

# Function to show usage
show_usage() {
    echo "Terraform Next.js Infrastructure Test Runner"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  all                 Run all test suites"
    echo "  modules             Run module unit tests"
    echo "  integration         Run integration tests"
    echo "  smoke               Run smoke tests"
    echo "  security            Run security tests"
    echo "  cost                Run cost optimization tests"
    echo "  quick               Run quick tests (short mode)"
    echo "  specific <test>     Run specific test by name"
    echo "  cleanup             Clean up test artifacts"
    echo "  help                Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_REGION          AWS region for testing (default: us-east-1)"
    echo "  TEST_ENVIRONMENT    Test environment name (default: test)"
    echo "  CLEANUP_RESOURCES   Whether to cleanup resources (default: true)"
    echo "  TEST_TIMEOUT        Test timeout duration (default: 30m)"
    echo "  PARALLEL            Number of parallel tests (default: 2)"
    echo ""
    echo "Examples:"
    echo "  $0 all                                    # Run all tests"
    echo "  $0 modules                                # Run only module tests"
    echo "  $0 specific TestS3WebsiteModule           # Run specific test"
    echo "  AWS_REGION=us-west-2 $0 quick             # Run quick tests in us-west-2"
    echo "  CLEANUP_RESOURCES=false $0 modules        # Run modules without cleanup"
}

# Function to show environment info
show_environment() {
    print_info "Test Environment Configuration:"
    echo "  AWS Region: $AWS_REGION"
    echo "  Test Environment: $TEST_ENVIRONMENT"
    echo "  Cleanup Resources: $CLEANUP_RESOURCES"
    echo "  Test Timeout: $TEST_TIMEOUT"
    echo "  Parallel Tests: $PARALLEL"
    echo ""
    
    print_info "AWS Identity:"
    aws sts get-caller-identity --output table 2>/dev/null || print_warning "Unable to get AWS identity"
    echo ""
}

# Main script logic
main() {
    local command=${1:-"help"}
    
    case $command in
        "all")
            check_prerequisites
            install_dependencies
            show_environment
            run_all_tests
            ;;
        "modules")
            check_prerequisites
            install_dependencies
            show_environment
            run_test_suite "modules" "Module unit tests"
            ;;
        "integration")
            check_prerequisites
            install_dependencies
            show_environment
            run_test_suite "integration" "Integration tests"
            ;;
        "smoke")
            check_prerequisites
            install_dependencies
            show_environment
            run_test_suite "smoke" "Smoke tests"
            ;;
        "security")
            check_prerequisites
            install_dependencies
            show_environment
            run_test_suite "security" "Security tests"
            ;;
        "cost")
            check_prerequisites
            install_dependencies
            show_environment
            run_test_suite "cost" "Cost optimization tests"
            ;;
        "quick")
            check_prerequisites
            install_dependencies
            show_environment
            run_quick_tests
            ;;
        "specific")
            check_prerequisites
            install_dependencies
            show_environment
            run_specific_test "$2"
            ;;
        "cleanup")
            cleanup
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            print_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"