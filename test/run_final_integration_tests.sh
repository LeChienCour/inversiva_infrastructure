#!/bin/bash

# Terraform Next.js Infrastructure - Final Integration Test Runner
# This script runs comprehensive end-to-end integration tests

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Default values
TEST_SUITE="all"
AWS_REGION="${AWS_REGION:-us-east-1}"
TEST_ENVIRONMENT="${TEST_ENVIRONMENT:-ci}"
CLEANUP_RESOURCES="${CLEANUP_RESOURCES:-true}"
TIMEOUT="${TIMEOUT:-60m}"
PARALLEL="${PARALLEL:-1}"
GENERATE_REPORT="${GENERATE_REPORT:-true}"

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Runs the final integration test suite for the Terraform Next.js Infrastructure project.

This script executes comprehensive end-to-end integration tests that validate:
- Complete infrastructure deployment
- Cross-environment isolation and resource separation  
- GitHub Actions deployment workflows validation
- Security penetration testing on deployed infrastructure

OPTIONS:
    -s, --suite SUITE           Test suite to run (all, e2e, github-actions, security, cross-env, readiness, final-suite)
    -r, --region REGION         AWS region for testing (default: us-east-1)
    -e, --environment ENV       Test environment identifier (default: ci)
    -c, --cleanup BOOL          Cleanup resources after tests (default: true)
    -t, --timeout DURATION      Test timeout duration (default: 60m)
    -p, --parallel COUNT        Number of parallel test executions (default: 1)
    --no-report                 Skip generating test report
    -h, --help                  Show this help message

EXAMPLES:
    $0 --suite all
    $0 --suite security --cleanup false
    $0 --suite e2e --region us-west-2 --timeout 45m
    $0 --suite final-suite --parallel 2

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--suite)
            TEST_SUITE="$2"
            shift 2
            ;;
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        -e|--environment)
            TEST_ENVIRONMENT="$2"
            shift 2
            ;;
        -c|--cleanup)
            CLEANUP_RESOURCES="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -p|--parallel)
            PARALLEL="$2"
            shift 2
            ;;
        --no-report)
            GENERATE_REPORT="false"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate test suite
case $TEST_SUITE in
    all|e2e|github-actions|security|cross-env|readiness|final-suite)
        ;;
    *)
        print_color $RED "Error: Invalid test suite '$TEST_SUITE'"
        print_color $YELLOW "Valid options: all, e2e, github-actions, security, cross-env, readiness, final-suite"
        exit 1
        ;;
esac

# Function to check prerequisites
check_prerequisites() {
    print_color $BLUE "Checking prerequisites..."
    
    # Check Go installation
    if command -v go >/dev/null 2>&1; then
        GO_VERSION=$(go version)
        print_color $GREEN "✓ Go: $GO_VERSION"
    else
        print_color $RED "✗ Go is not installed or not in PATH"
        exit 1
    fi
    
    # Check AWS CLI
    if command -v aws >/dev/null 2>&1; then
        AWS_VERSION=$(aws --version)
        print_color $GREEN "✓ AWS CLI: $AWS_VERSION"
    else
        print_color $RED "✗ AWS CLI is not installed or not in PATH"
        exit 1
    fi
    
    # Check Terraform
    if command -v terraform >/dev/null 2>&1; then
        TERRAFORM_VERSION=$(terraform version | head -n1)
        print_color $GREEN "✓ Terraform: $TERRAFORM_VERSION"
    else
        print_color $RED "✗ Terraform is not installed or not in PATH"
        exit 1
    fi
    
    # Check Terragrunt
    if command -v terragrunt >/dev/null 2>&1; then
        TERRAGRUNT_VERSION=$(terragrunt --version)
        print_color $GREEN "✓ Terragrunt: $TERRAGRUNT_VERSION"
    else
        print_color $RED "✗ Terragrunt is not installed or not in PATH"
        exit 1
    fi
    
    # Check AWS credentials
    if aws sts get-caller-identity >/dev/null 2>&1; then
        print_color $GREEN "✓ AWS credentials configured"
    else
        print_color $RED "✗ AWS credentials are not configured"
        exit 1
    fi
}

# Function to setup test environment
setup_test_environment() {
    print_color $BLUE "Setting up test environment..."
    
    # Set environment variables
    export AWS_REGION="$AWS_REGION"
    export TEST_ENVIRONMENT="$TEST_ENVIRONMENT"
    export CLEANUP_RESOURCES="$CLEANUP_RESOURCES"
    export GO_TEST_TIMEOUT="$TIMEOUT"
    
    # Create test results directory
    mkdir -p test-results
    
    # Install Go dependencies
    print_color $BLUE "Installing Go dependencies..."
    go mod download
    go mod tidy
    
    print_color $GREEN "Test environment initialized"
    print_color $CYAN "  AWS Region: $AWS_REGION"
    print_color $CYAN "  Test Environment: $TEST_ENVIRONMENT"
    print_color $CYAN "  Cleanup Resources: $CLEANUP_RESOURCES"
    print_color $CYAN "  Timeout: $TIMEOUT"
    print_color $CYAN "  Parallel: $PARALLEL"
}

# Function to run specific test suite
run_test_suite() {
    local suite_name="$1"
    local test_pattern="$2"
    local description="$3"
    
    print_color $BLUE "Running $description..."
    
    local start_time=$(date +%s)
    local success=true
    
    # Build test command
    local test_cmd="go test -v -timeout $TIMEOUT -parallel $PARALLEL"
    
    if [[ -n "$test_pattern" ]]; then
        test_cmd="$test_cmd -run $test_pattern"
    fi
    
    test_cmd="$test_cmd ./integration/..."
    
    # Run the test
    if eval "$test_cmd"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        local duration_formatted=$(printf '%02d:%02d:%02d' $((duration/3600)) $((duration%3600/60)) $((duration%60)))
        print_color $GREEN "✓ $description completed successfully (Duration: $duration_formatted)"
        echo "$suite_name:true:$duration" >> test-results/results.tmp
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        local duration_formatted=$(printf '%02d:%02d:%02d' $((duration/3600)) $((duration%3600/60)) $((duration%60)))
        print_color $RED "✗ $description failed (Duration: $duration_formatted)"
        echo "$suite_name:false:$duration" >> test-results/results.tmp
        success=false
    fi
    
    return $([ "$success" = true ] && echo 0 || echo 1)
}

# Function to generate test report
generate_test_report() {
    if [[ "$GENERATE_REPORT" != "true" ]]; then
        return
    fi
    
    print_color $BLUE "Generating test report..."
    
    local report_file="test-results/final-integration-test-report-$(date +%Y%m%d-%H%M%S).md"
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Start building the report
    cat > "$report_file" << EOF
# Final Integration Test Report

**Generated**: $current_time
**Test Suite**: $TEST_SUITE
**AWS Region**: $AWS_REGION
**Test Environment**: $TEST_ENVIRONMENT
**Cleanup Resources**: $CLEANUP_RESOURCES

## Test Results Summary

| Test Suite | Status | Duration |
|------------|--------|----------|
EOF
    
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    # Process results if file exists
    if [[ -f "test-results/results.tmp" ]]; then
        while IFS=':' read -r test_name success duration; do
            local status
            local duration_formatted=$(printf '%02d:%02d:%02d' $((duration/3600)) $((duration%3600/60)) $((duration%60)))
            
            if [[ "$success" == "true" ]]; then
                status="✅ PASS"
                ((passed_tests++))
            else
                status="❌ FAIL"
                ((failed_tests++))
            fi
            
            echo "| $test_name | $status | $duration_formatted |" >> "$report_file"
            ((total_tests++))
        done < test-results/results.tmp
        
        rm -f test-results/results.tmp
    fi
    
    local success_rate=0
    if [[ $total_tests -gt 0 ]]; then
        success_rate=$(( (passed_tests * 100) / total_tests ))
    fi
    
    # Add summary statistics
    cat >> "$report_file" << EOF

## Summary Statistics

- **Total Tests**: $total_tests
- **Passed**: $passed_tests
- **Failed**: $failed_tests
- **Success Rate**: $success_rate%

## Environment Details

- **AWS Region**: $AWS_REGION
- **Test Environment**: $TEST_ENVIRONMENT
- **Cleanup Resources**: $CLEANUP_RESOURCES
- **Test Timeout**: $TIMEOUT
- **Parallel Execution**: $PARALLEL

EOF
    
    if [[ $failed_tests -gt 0 ]]; then
        cat >> "$report_file" << EOF
## ⚠️ Failed Tests

Some tests failed and require attention. Please review the detailed logs above.

### Troubleshooting Steps

1. Check the detailed test logs above
2. Verify AWS permissions and resource availability
3. Ensure all prerequisites are installed and configured
4. Check for resource conflicts or naming collisions
5. Review security group and network configurations
6. Validate Terraform and Terragrunt configurations

EOF
    else
        cat >> "$report_file" << EOF
## ✅ All Tests Passed

Congratulations! All integration tests passed successfully. The infrastructure is ready for deployment.

EOF
    fi
    
    print_color $GREEN "Test report generated: $report_file"
    
    # Also output summary to console
    print_color $MAGENTA "$(printf '=%.0s' {1..80})"
    print_color $MAGENTA "FINAL INTEGRATION TEST RESULTS"
    print_color $MAGENTA "$(printf '=%.0s' {1..80})"
    print_color $WHITE "Total Tests: $total_tests"
    print_color $GREEN "Passed: $passed_tests"
    print_color $RED "Failed: $failed_tests"
    print_color $CYAN "Success Rate: $success_rate%"
    print_color $MAGENTA "$(printf '=%.0s' {1..80})"
    
    return $failed_tests
}

# Main execution function
main() {
    local start_time=$(date +%s)
    
    print_color $MAGENTA "$(printf '=%.0s' {1..80})"
    print_color $MAGENTA "TERRAFORM NEXT.JS INFRASTRUCTURE - FINAL INTEGRATION TESTS"
    print_color $MAGENTA "$(printf '=%.0s' {1..80})"
    
    # Check prerequisites
    check_prerequisites
    
    # Setup test environment
    setup_test_environment
    
    # Initialize results file
    rm -f test-results/results.tmp
    
    # Run tests based on selected suite
    local overall_success=true
    
    case $TEST_SUITE in
        "all")
            print_color $YELLOW "Running all integration test suites..."
            
            run_test_suite "Infrastructure Readiness" "TestInfrastructureReadiness" "Infrastructure Readiness Tests" || overall_success=false
            run_test_suite "GitHub Actions Workflows" "TestGitHubActionsWorkflows|TestWorkflowSyntax|TestWorkflowSecrets" "GitHub Actions Workflow Tests" || overall_success=false
            run_test_suite "Cross-Environment Isolation" "TestCrossEnvironmentIsolation|TestResourceSeparation" "Cross-Environment Isolation Tests" || overall_success=false
            run_test_suite "End-to-End Deployment" "TestCompleteInfrastructureDeployment" "End-to-End Infrastructure Deployment Tests" || overall_success=false
            run_test_suite "Security Penetration" "TestSecurityPenetrationTesting" "Security Penetration Tests" || overall_success=false
            ;;
            
        "final-suite")
            run_test_suite "Final Integration Suite" "TestFinalIntegrationSuite" "Complete Final Integration Test Suite" || overall_success=false
            ;;
            
        "e2e")
            run_test_suite "End-to-End Deployment" "TestCompleteInfrastructureDeployment" "End-to-End Infrastructure Deployment Tests" || overall_success=false
            ;;
            
        "github-actions")
            run_test_suite "GitHub Actions Workflows" "TestGitHubActionsWorkflows|TestWorkflowSyntax|TestWorkflowSecrets" "GitHub Actions Workflow Tests" || overall_success=false
            ;;
            
        "security")
            run_test_suite "Security Penetration" "TestSecurityPenetrationTesting" "Security Penetration Tests" || overall_success=false
            ;;
            
        "cross-env")
            run_test_suite "Cross-Environment Isolation" "TestCrossEnvironmentIsolation|TestResourceSeparation" "Cross-Environment Isolation Tests" || overall_success=false
            ;;
            
        "readiness")
            run_test_suite "Infrastructure Readiness" "TestInfrastructureReadiness|TestComplianceValidation" "Infrastructure Readiness Tests" || overall_success=false
            ;;
    esac
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    local total_duration_formatted=$(printf '%02d:%02d:%02d' $((total_duration/3600)) $((total_duration%3600/60)) $((total_duration%60)))
    
    # Generate report and get failed count
    local failed_count
    generate_test_report
    failed_count=$?
    
    print_color $CYAN "\nTotal execution time: $total_duration_formatted"
    
    # Determine exit code
    if [[ $failed_count -gt 0 ]] || [[ "$overall_success" != "true" ]]; then
        print_color $RED "\n❌ $failed_count test suite(s) failed"
        exit 1
    else
        print_color $GREEN "\n✅ All test suites passed successfully!"
        exit 0
    fi
}

# Execute main function
main "$@"