#!/bin/bash

# Cost Monitoring and Reporting Script
# This script provides utilities for monitoring AWS costs and generating reports

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
DEFAULT_DAYS=30
DEFAULT_GRANULARITY="DAILY"
DEFAULT_METRICS="BlendedCost"

# Help function
show_help() {
    cat << EOF
Cost Monitoring and Reporting Script

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    report      Generate cost report for the project
    breakdown   Show cost breakdown by service
    trends      Show cost trends over time
    budget      Check budget status and alerts
    optimize    Show cost optimization recommendations
    help        Show this help message

OPTIONS:
    -d, --days DAYS         Number of days to analyze [default: $DEFAULT_DAYS]
    -g, --granularity GRAN  Granularity (DAILY/MONTHLY) [default: $DEFAULT_GRANULARITY]
    -m, --metrics METRICS   Cost metrics (BlendedCost/UnblendedCost) [default: $DEFAULT_METRICS]
    -e, --environment ENV   Filter by environment (dev/prod)
    -s, --service SERVICE   Filter by AWS service
    -f, --format FORMAT     Output format (table/json/csv) [default: table]
    -o, --output FILE       Output file path
    -v, --verbose           Verbose output

EXAMPLES:
    # Generate monthly cost report
    $0 report -d 30 -g MONTHLY
    
    # Show cost breakdown by service for dev environment
    $0 breakdown -e dev -d 7
    
    # Show cost trends for the last 90 days
    $0 trends -d 90
    
    # Check budget status
    $0 budget
    
    # Get cost optimization recommendations
    $0 optimize -e prod

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

# Check if AWS CLI is configured
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed or not in PATH"
        return 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI is not configured or credentials are invalid"
        log_info "Run 'aws configure' to set up your credentials"
        return 1
    fi
    
    log_info "AWS CLI is configured and ready"
}

# Check if jq is available
check_jq() {
    if ! command -v jq &> /dev/null; then
        log_warning "jq is not installed. JSON output will be raw"
        return 1
    fi
    return 0
}

# Get project tags for filtering
get_project_tags() {
    local environment=$1
    local tags=""
    
    # Try to get project name from terragrunt config
    if [ -f "$PROJECT_ROOT/terragrunt.hcl" ]; then
        local project_name
        project_name=$(grep -o 'project_name.*=.*"[^"]*"' "$PROJECT_ROOT/terragrunt.hcl" | cut -d'"' -f2 2>/dev/null || echo "")
        if [ -n "$project_name" ]; then
            tags="Key=Project,Values=$project_name"
        fi
    fi
    
    # Add environment filter if specified
    if [ -n "$environment" ]; then
        if [ -n "$tags" ]; then
            tags="$tags Key=Environment,Values=$environment"
        else
            tags="Key=Environment,Values=$environment"
        fi
    fi
    
    echo "$tags"
}

# Generate cost report
generate_cost_report() {
    local days=$1
    local granularity=$2
    local metrics=$3
    local environment=$4
    local format=$5
    local output_file=$6
    local verbose=$7
    
    log_info "Generating cost report..."
    log_info "Period: Last $days days"
    log_info "Granularity: $granularity"
    log_info "Metrics: $metrics"
    
    # Calculate date range
    local start_date
    local end_date
    start_date=$(date -d "$days days ago" +%Y-%m-%d 2>/dev/null || date -v "-${days}d" +%Y-%m-%d 2>/dev/null)
    end_date=$(date +%Y-%m-%d)
    
    log_info "Date range: $start_date to $end_date"
    
    # Build AWS CLI command
    local cmd="aws ce get-cost-and-usage"
    cmd="$cmd --time-period Start=$start_date,End=$end_date"
    cmd="$cmd --granularity $granularity"
    cmd="$cmd --metrics $metrics"
    
    # Add group by for service breakdown
    cmd="$cmd --group-by Type=DIMENSION,Key=SERVICE"
    
    # Add filters if specified
    local tags
    tags=$(get_project_tags "$environment")
    if [ -n "$tags" ]; then
        cmd="$cmd --filter Dimensions={Key=TAG,Values=[$tags]}"
    fi
    
    if [ "$verbose" = "true" ]; then
        log_info "Executing: $cmd"
    fi
    
    # Execute command and process output
    local result
    result=$(eval "$cmd" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to retrieve cost data"
        return 1
    fi
    
    # Process and display results
    if [ "$format" = "json" ]; then
        if [ -n "$output_file" ]; then
            echo "$result" > "$output_file"
            log_success "Cost report saved to: $output_file"
        else
            echo "$result"
        fi
    elif [ "$format" = "csv" ]; then
        # Convert to CSV format
        local csv_output
        if check_jq; then
            csv_output=$(echo "$result" | jq -r '
                ["Date", "Service", "Amount", "Unit"] as $header |
                $header,
                (.ResultsByTime[] as $time |
                    $time.TimePeriod.Start as $date |
                    $time.Groups[] |
                    [$date, .Keys[0], .Metrics.BlendedCost.Amount, .Metrics.BlendedCost.Unit]
                ) | @csv
            ')
        else
            log_warning "jq not available, cannot convert to CSV format"
            csv_output="$result"
        fi
        
        if [ -n "$output_file" ]; then
            echo "$csv_output" > "$output_file"
            log_success "Cost report saved to: $output_file"
        else
            echo "$csv_output"
        fi
    else
        # Table format (default)
        display_cost_table "$result" "$verbose"
    fi
}

# Display cost data in table format
display_cost_table() {
    local result=$1
    local verbose=$2
    
    if check_jq; then
        echo ""
        echo "Cost Report Summary:"
        echo "==================="
        
        # Calculate total cost
        local total_cost
        total_cost=$(echo "$result" | jq -r '
            [.ResultsByTime[].Groups[].Metrics.BlendedCost.Amount | tonumber] | add
        ' 2>/dev/null || echo "0")
        
        echo "Total Cost: \$$(printf "%.2f" "$total_cost")"
        echo ""
        
        # Show top services by cost
        echo "Top Services by Cost:"
        echo "--------------------"
        echo "$result" | jq -r '
            [.ResultsByTime[].Groups[] | {
                service: .Keys[0],
                cost: (.Metrics.BlendedCost.Amount | tonumber)
            }] |
            group_by(.service) |
            map({
                service: .[0].service,
                total_cost: (map(.cost) | add)
            }) |
            sort_by(.total_cost) | reverse |
            .[:10] |
            .[] |
            "\(.service): $\(.total_cost | . * 100 | round / 100)"
        ' | column -t
        
        if [ "$verbose" = "true" ]; then
            echo ""
            echo "Daily Breakdown:"
            echo "---------------"
            echo "$result" | jq -r '
                .ResultsByTime[] |
                "\(.TimePeriod.Start): $\([.Groups[].Metrics.BlendedCost.Amount | tonumber] | add | . * 100 | round / 100)"
            '
        fi
    else
        log_warning "jq not available, showing raw JSON output"
        echo "$result"
    fi
}

# Show cost breakdown by service
show_cost_breakdown() {
    local days=$1
    local environment=$2
    local service=$3
    local verbose=$4
    
    log_info "Generating cost breakdown..."
    
    # Use the report function with service-specific filtering
    local cmd_args="-d $days -g DAILY -f table"
    if [ -n "$environment" ]; then
        cmd_args="$cmd_args -e $environment"
    fi
    if [ "$verbose" = "true" ]; then
        cmd_args="$cmd_args -v"
    fi
    
    generate_cost_report $days "DAILY" "BlendedCost" "$environment" "table" "" "$verbose"
}

# Show cost trends
show_cost_trends() {
    local days=$1
    local verbose=$2
    
    log_info "Analyzing cost trends for the last $days days..."
    
    # Get daily costs
    local start_date
    local end_date
    start_date=$(date -d "$days days ago" +%Y-%m-%d 2>/dev/null || date -v "-${days}d" +%Y-%m-%d 2>/dev/null)
    end_date=$(date +%Y-%m-%d)
    
    local result
    result=$(aws ce get-cost-and-usage \
        --time-period Start="$start_date",End="$end_date" \
        --granularity DAILY \
        --metrics BlendedCost 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to retrieve cost trend data"
        return 1
    fi
    
    if check_jq; then
        echo ""
        echo "Cost Trends Analysis:"
        echo "===================="
        
        # Calculate average daily cost
        local avg_cost
        avg_cost=$(echo "$result" | jq -r '
            [.ResultsByTime[].Total.BlendedCost.Amount | tonumber] |
            (add / length) | . * 100 | round / 100
        ')
        
        echo "Average Daily Cost: \$$avg_cost"
        
        # Show trend direction
        local first_week_avg
        local last_week_avg
        first_week_avg=$(echo "$result" | jq -r '
            [.ResultsByTime[:7][].Total.BlendedCost.Amount | tonumber] |
            (add / length) | . * 100 | round / 100
        ')
        last_week_avg=$(echo "$result" | jq -r '
            [.ResultsByTime[-7:][].Total.BlendedCost.Amount | tonumber] |
            (add / length) | . * 100 | round / 100
        ')
        
        local trend_direction
        if (( $(echo "$last_week_avg > $first_week_avg" | bc -l 2>/dev/null || echo "0") )); then
            trend_direction="INCREASING"
            echo "Trend: $trend_direction (↗)"
        elif (( $(echo "$last_week_avg < $first_week_avg" | bc -l 2>/dev/null || echo "0") )); then
            trend_direction="DECREASING"
            echo "Trend: $trend_direction (↘)"
        else
            trend_direction="STABLE"
            echo "Trend: $trend_direction (→)"
        fi
        
        if [ "$verbose" = "true" ]; then
            echo ""
            echo "Daily Costs:"
            echo "-----------"
            echo "$result" | jq -r '
                .ResultsByTime[] |
                "\(.TimePeriod.Start): $\(.Total.BlendedCost.Amount | tonumber | . * 100 | round / 100)"
            '
        fi
    else
        log_warning "jq not available, showing raw JSON output"
        echo "$result"
    fi
}

# Check budget status
check_budget_status() {
    local verbose=$1
    
    log_info "Checking budget status..."
    
    # Get budgets
    local budgets
    budgets=$(aws budgets describe-budgets --account-id "$(aws sts get-caller-identity --query Account --output text)" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_warning "Could not retrieve budget information"
        log_info "You may need to create budgets first or check permissions"
        return 1
    fi
    
    if check_jq; then
        local budget_count
        budget_count=$(echo "$budgets" | jq '.Budgets | length')
        
        if [ "$budget_count" -eq 0 ]; then
            log_warning "No budgets configured"
            log_info "Consider creating budgets to monitor costs"
        else
            echo ""
            echo "Budget Status:"
            echo "============="
            
            echo "$budgets" | jq -r '
                .Budgets[] |
                "Budget: \(.BudgetName)",
                "  Limit: $\(.BudgetLimit.Amount) \(.BudgetLimit.Unit)",
                "  Type: \(.BudgetType)",
                "  Time Period: \(.TimePeriod.Start) to \(.TimePeriod.End // "Ongoing")",
                ""
            '
        fi
    else
        log_warning "jq not available, showing raw JSON output"
        echo "$budgets"
    fi
}

# Show cost optimization recommendations
show_optimization_recommendations() {
    local environment=$1
    local verbose=$2
    
    log_info "Generating cost optimization recommendations..."
    
    echo ""
    echo "Cost Optimization Recommendations:"
    echo "================================="
    
    # Check for unused resources (this is a simplified check)
    echo "1. Resource Utilization Analysis:"
    echo "   - Review CloudFront cache hit ratios"
    echo "   - Check S3 storage class optimization"
    echo "   - Monitor Cognito active users"
    echo ""
    
    # Environment-specific recommendations
    if [ "$environment" = "dev" ]; then
        echo "2. Development Environment Optimizations:"
        echo "   - Use S3 Standard-IA for non-critical data"
        echo "   - Consider CloudFront PriceClass_100"
        echo "   - Implement lifecycle policies for temporary data"
        echo ""
    elif [ "$environment" = "prod" ]; then
        echo "2. Production Environment Optimizations:"
        echo "   - Monitor CloudFront cache performance"
        echo "   - Review S3 access patterns for storage class optimization"
        echo "   - Consider Reserved Capacity for predictable workloads"
        echo ""
    fi
    
    echo "3. General Recommendations:"
    echo "   - Enable detailed billing and cost allocation tags"
    echo "   - Set up cost alerts and budgets"
    echo "   - Regular review of AWS Cost Explorer"
    echo "   - Consider AWS Cost Anomaly Detection"
    echo ""
    
    # Get actual recommendations from AWS if available
    if [ "$verbose" = "true" ]; then
        log_info "Checking for AWS Cost Explorer recommendations..."
        
        # Try to get rightsizing recommendations
        local rightsizing
        rightsizing=$(aws ce get-rightsizing-recommendation --service EC2-Instance 2>/dev/null || echo "")
        
        if [ -n "$rightsizing" ] && check_jq; then
            local rec_count
            rec_count=$(echo "$rightsizing" | jq '.RightsizingRecommendations | length')
            
            if [ "$rec_count" -gt 0 ]; then
                echo "4. AWS Rightsizing Recommendations:"
                echo "$rightsizing" | jq -r '
                    .RightsizingRecommendations[] |
                    "   - \(.CurrentInstance.ResourceId): \(.RightsizingType)"
                '
                echo ""
            fi
        fi
    fi
}

# Main function
main() {
    local command=""
    local days="$DEFAULT_DAYS"
    local granularity="$DEFAULT_GRANULARITY"
    local metrics="$DEFAULT_METRICS"
    local environment=""
    local service=""
    local format="table"
    local output_file=""
    local verbose="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            report|breakdown|trends|budget|optimize|help)
                command="$1"
                shift
                ;;
            -d|--days)
                days="$2"
                shift 2
                ;;
            -g|--granularity)
                granularity="$2"
                shift 2
                ;;
            -m|--metrics)
                metrics="$2"
                shift 2
                ;;
            -e|--environment)
                environment="$2"
                shift 2
                ;;
            -s|--service)
                service="$2"
                shift 2
                ;;
            -f|--format)
                format="$2"
                shift 2
                ;;
            -o|--output)
                output_file="$2"
                shift 2
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
    
    # Check AWS CLI
    if ! check_aws_cli; then
        exit 1
    fi
    
    # Execute command
    case $command in
        report)
            generate_cost_report "$days" "$granularity" "$metrics" "$environment" "$format" "$output_file" "$verbose"
            ;;
        breakdown)
            show_cost_breakdown "$days" "$environment" "$service" "$verbose"
            ;;
        trends)
            show_cost_trends "$days" "$verbose"
            ;;
        budget)
            check_budget_status "$verbose"
            ;;
        optimize)
            show_optimization_recommendations "$environment" "$verbose"
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