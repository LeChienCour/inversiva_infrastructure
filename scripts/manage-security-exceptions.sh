#!/bin/bash

# Security Exception Management Script
# This script helps manage Checkov security exceptions and baseline updates

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BASELINE_FILE="$PROJECT_ROOT/.checkov.baseline"
CONFIG_FILE="$PROJECT_ROOT/.checkov.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to show usage
show_usage() {
    cat << EOF
Security Exception Management Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    list                    List all current security exceptions
    add                     Add a new security exception
    remove                  Remove a security exception
    review                  Review exceptions that need renewal
    update-baseline         Update baseline from latest scan results
    validate                Validate current exceptions and baseline
    report                  Generate security exceptions report

Options:
    --check-id ID          Specific Checkov check ID (e.g., CKV_AWS_18)
    --environment ENV      Environment (dev, prod, all)
    --resource RESOURCE    Specific resource pattern
    --justification TEXT   Justification for the exception
    --approved-by NAME     Name of person approving the exception
    --review-date DATE     Date when exception should be reviewed (YYYY-MM-DD)
    --help                 Show this help message

Examples:
    $0 list
    $0 add --check-id CKV_AWS_18 --environment dev --justification "Cost optimization"
    $0 remove --check-id CKV_AWS_18 --environment dev
    $0 review
    $0 update-baseline
    $0 report

EOF
}

# Function to list current exceptions
list_exceptions() {
    print_color $BLUE "Current Security Exceptions:"
    echo
    
    if [ ! -f "$BASELINE_FILE" ]; then
        print_color $YELLOW "No baseline file found at $BASELINE_FILE"
        return
    fi
    
    # Parse and display exceptions from baseline file
    jq -r '
        .approved_exceptions | to_entries[] | 
        "Check ID: \(.key)
Description: \(.value.description)
Justification: \(.value.justification)
Approved by: \(.value.approved_by)
Approval date: \(.value.approval_date)
Review date: \(.value.review_date)
Environments: \(.value.environments | join(", "))
Resources: \(.value.resources | join(", "))
---"
    ' "$BASELINE_FILE" 2>/dev/null || print_color $RED "Error parsing baseline file"
}

# Function to add new exception
add_exception() {
    local check_id=""
    local environment=""
    local resource=""
    local justification=""
    local approved_by=""
    local review_date=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check-id)
                check_id="$2"
                shift 2
                ;;
            --environment)
                environment="$2"
                shift 2
                ;;
            --resource)
                resource="$2"
                shift 2
                ;;
            --justification)
                justification="$2"
                shift 2
                ;;
            --approved-by)
                approved_by="$2"
                shift 2
                ;;
            --review-date)
                review_date="$2"
                shift 2
                ;;
            *)
                print_color $RED "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    # Validate required parameters
    if [ -z "$check_id" ] || [ -z "$environment" ] || [ -z "$justification" ] || [ -z "$approved_by" ]; then
        print_color $RED "Missing required parameters. Need: --check-id, --environment, --justification, --approved-by"
        return 1
    fi
    
    # Set default review date if not provided (6 months from now)
    if [ -z "$review_date" ]; then
        review_date=$(date -d "+6 months" +%Y-%m-%d)
    fi
    
    # Set default resource if not provided
    if [ -z "$resource" ]; then
        resource="*"
    fi
    
    print_color $BLUE "Adding security exception:"
    echo "Check ID: $check_id"
    echo "Environment: $environment"
    echo "Resource: $resource"
    echo "Justification: $justification"
    echo "Approved by: $approved_by"
    echo "Review date: $review_date"
    echo
    
    # Confirm addition
    read -p "Add this exception? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_color $YELLOW "Exception not added"
        return 0
    fi
    
    # Create backup of baseline file
    if [ -f "$BASELINE_FILE" ]; then
        cp "$BASELINE_FILE" "$BASELINE_FILE.backup.$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Add exception to baseline file using jq
    local temp_file=$(mktemp)
    local current_date=$(date +%Y-%m-%d)
    
    if [ ! -f "$BASELINE_FILE" ]; then
        # Create new baseline file
        cat > "$temp_file" << EOF
{
  "version": "1.0",
  "description": "Checkov baseline file for approved security exceptions",
  "baseline_date": "$current_date",
  "approved_exceptions": {},
  "soft_fail_exceptions": {}
}
EOF
    else
        cp "$BASELINE_FILE" "$temp_file"
    fi
    
    # Add the new exception
    jq --arg check_id "$check_id" \
       --arg description "Security exception for $check_id" \
       --arg justification "$justification" \
       --arg approved_by "$approved_by" \
       --arg approval_date "$current_date" \
       --arg review_date "$review_date" \
       --arg environment "$environment" \
       --arg resource "$resource" \
       '.approved_exceptions[$check_id] = {
         "description": $description,
         "justification": $justification,
         "approved_by": $approved_by,
         "approval_date": $approval_date,
         "review_date": $review_date,
         "environments": [$environment],
         "resources": [$resource]
       }' "$temp_file" > "$BASELINE_FILE"
    
    rm "$temp_file"
    
    print_color $GREEN "Exception added successfully!"
}

# Function to remove exception
remove_exception() {
    local check_id=""
    local environment=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check-id)
                check_id="$2"
                shift 2
                ;;
            --environment)
                environment="$2"
                shift 2
                ;;
            *)
                print_color $RED "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    if [ -z "$check_id" ]; then
        print_color $RED "Missing required parameter: --check-id"
        return 1
    fi
    
    if [ ! -f "$BASELINE_FILE" ]; then
        print_color $RED "Baseline file not found"
        return 1
    fi
    
    # Create backup
    cp "$BASELINE_FILE" "$BASELINE_FILE.backup.$(date +%Y%m%d-%H%M%S)"
    
    # Remove exception
    local temp_file=$(mktemp)
    jq --arg check_id "$check_id" 'del(.approved_exceptions[$check_id])' "$BASELINE_FILE" > "$temp_file"
    mv "$temp_file" "$BASELINE_FILE"
    
    print_color $GREEN "Exception removed: $check_id"
}

# Function to review exceptions needing renewal
review_exceptions() {
    print_color $BLUE "Reviewing exceptions that need renewal:"
    echo
    
    if [ ! -f "$BASELINE_FILE" ]; then
        print_color $YELLOW "No baseline file found"
        return
    fi
    
    local current_date=$(date +%Y-%m-%d)
    
    # Find exceptions that need review (review date is past or within 30 days)
    jq -r --arg current_date "$current_date" '
        .approved_exceptions | to_entries[] | 
        select(.value.review_date <= ($current_date | strptime("%Y-%m-%d") | mktime + (30*24*3600) | strftime("%Y-%m-%d"))) |
        "⚠️  Check ID: \(.key)
   Review Date: \(.value.review_date)
   Description: \(.value.description)
   Approved by: \(.value.approved_by)
   ---"
    ' "$BASELINE_FILE" 2>/dev/null || print_color $RED "Error parsing baseline file"
}

# Function to update baseline from scan results
update_baseline() {
    print_color $BLUE "Updating baseline from latest scan results..."
    
    # Run Checkov to generate current results
    local temp_results=$(mktemp)
    
    cd "$PROJECT_ROOT"
    
    print_color $YELLOW "Running Checkov scan to generate baseline..."
    checkov --config-file .checkov.yml --directory . --output json --output-file-path "$temp_results" --create-baseline || true
    
    if [ -f "${temp_results}/results_json.json" ]; then
        print_color $GREEN "Baseline updated from scan results"
    else
        print_color $RED "Failed to generate scan results"
        rm -f "$temp_results"
        return 1
    fi
    
    rm -f "$temp_results"
}

# Function to validate current exceptions
validate_exceptions() {
    print_color $BLUE "Validating current security exceptions..."
    
    if [ ! -f "$BASELINE_FILE" ]; then
        print_color $RED "Baseline file not found"
        return 1
    fi
    
    # Validate JSON syntax
    if ! jq empty "$BASELINE_FILE" 2>/dev/null; then
        print_color $RED "Invalid JSON in baseline file"
        return 1
    fi
    
    # Check for required fields
    local validation_errors=0
    
    jq -r '.approved_exceptions | to_entries[] | .key' "$BASELINE_FILE" | while read -r check_id; do
        local description=$(jq -r --arg check_id "$check_id" '.approved_exceptions[$check_id].description // empty' "$BASELINE_FILE")
        local justification=$(jq -r --arg check_id "$check_id" '.approved_exceptions[$check_id].justification // empty' "$BASELINE_FILE")
        local approved_by=$(jq -r --arg check_id "$check_id" '.approved_exceptions[$check_id].approved_by // empty' "$BASELINE_FILE")
        
        if [ -z "$description" ] || [ -z "$justification" ] || [ -z "$approved_by" ]; then
            print_color $RED "Incomplete exception for $check_id"
            validation_errors=$((validation_errors + 1))
        fi
    done
    
    if [ $validation_errors -eq 0 ]; then
        print_color $GREEN "All exceptions are valid"
    else
        print_color $RED "Found $validation_errors validation errors"
        return 1
    fi
}

# Function to generate security exceptions report
generate_report() {
    print_color $BLUE "Generating security exceptions report..."
    
    local report_file="$PROJECT_ROOT/security-exceptions-report.md"
    local current_date=$(date)
    
    cat > "$report_file" << EOF
# Security Exceptions Report

**Generated**: $current_date
**Baseline File**: .checkov.baseline
**Configuration**: .checkov.yml

## Summary

EOF
    
    if [ -f "$BASELINE_FILE" ]; then
        local total_exceptions=$(jq '.approved_exceptions | length' "$BASELINE_FILE" 2>/dev/null || echo "0")
        local soft_fail_exceptions=$(jq '.soft_fail_exceptions | length' "$BASELINE_FILE" 2>/dev/null || echo "0")
        
        cat >> "$report_file" << EOF
- **Total Approved Exceptions**: $total_exceptions
- **Soft Fail Exceptions**: $soft_fail_exceptions

## Approved Exceptions

EOF
        
        jq -r '
            .approved_exceptions | to_entries[] | 
            "### \(.key)

**Description**: \(.value.description)
**Justification**: \(.value.justification)
**Approved By**: \(.value.approved_by)
**Approval Date**: \(.value.approval_date)
**Review Date**: \(.value.review_date)
**Environments**: \(.value.environments | join(", "))
**Resources**: \(.value.resources | join(", "))

---
"
        ' "$BASELINE_FILE" >> "$report_file" 2>/dev/null || echo "Error parsing exceptions" >> "$report_file"
        
        cat >> "$report_file" << EOF

## Soft Fail Exceptions

EOF
        
        jq -r '
            .soft_fail_exceptions | to_entries[] | 
            "### \(.key)

**Description**: \(.value.description)
**Justification**: \(.value.justification)
**Environments**: \(.value.environments | join(", "))

---
"
        ' "$BASELINE_FILE" >> "$report_file" 2>/dev/null || echo "No soft fail exceptions" >> "$report_file"
        
    else
        echo "- **No baseline file found**" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## Recommendations

1. Review all exceptions quarterly
2. Update justifications when business requirements change
3. Remove exceptions that are no longer needed
4. Ensure all exceptions have proper approval documentation
5. Monitor for new security checks that might need exceptions

## Next Review Date

$(date -d "+3 months" +%Y-%m-%d)

EOF
    
    print_color $GREEN "Report generated: $report_file"
}

# Main script logic
case "${1:-}" in
    list)
        list_exceptions
        ;;
    add)
        shift
        add_exception "$@"
        ;;
    remove)
        shift
        remove_exception "$@"
        ;;
    review)
        review_exceptions
        ;;
    update-baseline)
        update_baseline
        ;;
    validate)
        validate_exceptions
        ;;
    report)
        generate_report
        ;;
    --help|help|"")
        show_usage
        ;;
    *)
        print_color $RED "Unknown command: $1"
        echo
        show_usage
        exit 1
        ;;
esac