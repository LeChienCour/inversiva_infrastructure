#!/bin/bash

# Monitoring Health Check Script
# This script checks the health and status of monitoring infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="dev"
PROJECT_NAME="nextjs-infrastructure"
REGION="us-east-1"

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "SUCCESS")
            echo -e "${GREEN}✓${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}✗${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ${NC} $message"
            ;;
    esac
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -e, --environment    Environment (dev/prod) [default: dev]"
    echo "  -p, --project        Project name [default: nextjs-infrastructure]"
    echo "  -r, --region         AWS region [default: us-east-1]"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -e prod -p my-app -r us-west-2"
    echo "  $0 --environment dev --project nextjs-app"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -p|--project)
            PROJECT_NAME="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate environment
if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
    print_status "ERROR" "Environment must be 'dev' or 'prod'"
    exit 1
fi

print_status "INFO" "Checking monitoring health for $PROJECT_NAME ($ENVIRONMENT) in $REGION"
echo ""

# Check AWS CLI availability
if ! command -v aws &> /dev/null; then
    print_status "ERROR" "AWS CLI is not installed or not in PATH"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    print_status "ERROR" "AWS credentials not configured or invalid"
    exit 1
fi

print_status "SUCCESS" "AWS CLI and credentials are configured"

# Check SNS Topic
SNS_TOPIC_NAME="${PROJECT_NAME}-${ENVIRONMENT}-alerts"
print_status "INFO" "Checking SNS topic: $SNS_TOPIC_NAME"

if aws sns list-topics --region "$REGION" --query "Topics[?contains(TopicArn, '$SNS_TOPIC_NAME')]" --output text | grep -q "$SNS_TOPIC_NAME"; then
    print_status "SUCCESS" "SNS topic exists"
    
    # Check subscriptions
    TOPIC_ARN=$(aws sns list-topics --region "$REGION" --query "Topics[?contains(TopicArn, '$SNS_TOPIC_NAME')].TopicArn" --output text)
    SUBSCRIPTION_COUNT=$(aws sns list-subscriptions-by-topic --topic-arn "$TOPIC_ARN" --region "$REGION" --query 'length(Subscriptions)')
    
    if [[ "$SUBSCRIPTION_COUNT" -gt 0 ]]; then
        print_status "SUCCESS" "SNS topic has $SUBSCRIPTION_COUNT subscription(s)"
    else
        print_status "WARNING" "SNS topic has no subscriptions"
    fi
else
    print_status "ERROR" "SNS topic not found"
fi

# Check CloudWatch Dashboard
DASHBOARD_NAME="${PROJECT_NAME}-${ENVIRONMENT}-infrastructure"
print_status "INFO" "Checking CloudWatch dashboard: $DASHBOARD_NAME"

if aws cloudwatch list-dashboards --region "$REGION" --query "DashboardEntries[?DashboardName=='$DASHBOARD_NAME']" --output text | grep -q "$DASHBOARD_NAME"; then
    print_status "SUCCESS" "CloudWatch dashboard exists"
else
    print_status "ERROR" "CloudWatch dashboard not found"
fi

# Check Budget
BUDGET_NAME="${PROJECT_NAME}-${ENVIRONMENT}-budget"
print_status "INFO" "Checking budget: $BUDGET_NAME"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if aws budgets describe-budget --account-id "$ACCOUNT_ID" --budget-name "$BUDGET_NAME" &> /dev/null; then
    print_status "SUCCESS" "Budget exists"
    
    # Get budget utilization
    BUDGET_INFO=$(aws budgets describe-budget --account-id "$ACCOUNT_ID" --budget-name "$BUDGET_NAME" --query 'Budget.{Limit:BudgetLimit.Amount,Actual:CalculatedSpend.ActualSpend.Amount}' --output json)
    LIMIT=$(echo "$BUDGET_INFO" | jq -r '.Limit')
    ACTUAL=$(echo "$BUDGET_INFO" | jq -r '.Actual // "0"')
    
    if [[ "$ACTUAL" != "null" && "$ACTUAL" != "0" ]]; then
        PERCENTAGE=$(echo "scale=1; $ACTUAL * 100 / $LIMIT" | bc)
        print_status "INFO" "Budget utilization: \$${ACTUAL}/\$${LIMIT} (${PERCENTAGE}%)"
    else
        print_status "INFO" "Budget utilization: No spending data available yet"
    fi
else
    print_status "ERROR" "Budget not found"
fi

# Check CloudTrail (only for prod)
if [[ "$ENVIRONMENT" == "prod" ]]; then
    TRAIL_NAME="${PROJECT_NAME}-${ENVIRONMENT}-security-trail"
    print_status "INFO" "Checking CloudTrail: $TRAIL_NAME"
    
    if aws cloudtrail describe-trails --region "$REGION" --query "trailList[?Name=='$TRAIL_NAME']" --output text | grep -q "$TRAIL_NAME"; then
        print_status "SUCCESS" "CloudTrail exists"
        
        # Check if logging is enabled
        LOGGING_STATUS=$(aws cloudtrail get-trail-status --name "$TRAIL_NAME" --region "$REGION" --query 'IsLogging' --output text)
        if [[ "$LOGGING_STATUS" == "True" ]]; then
            print_status "SUCCESS" "CloudTrail logging is enabled"
        else
            print_status "WARNING" "CloudTrail logging is disabled"
        fi
    else
        print_status "ERROR" "CloudTrail not found"
    fi
else
    print_status "INFO" "CloudTrail disabled for development environment (cost optimization)"
fi

# Check CloudWatch Alarms
print_status "INFO" "Checking CloudWatch alarms"

ALARM_PREFIX="${PROJECT_NAME}-${ENVIRONMENT}"
ALARM_COUNT=$(aws cloudwatch describe-alarms --region "$REGION" --query "MetricAlarms[?starts_with(AlarmName, '$ALARM_PREFIX')] | length(@)")

if [[ "$ALARM_COUNT" -gt 0 ]]; then
    print_status "SUCCESS" "Found $ALARM_COUNT CloudWatch alarm(s)"
    
    # Check alarm states
    ALARM_STATES=$(aws cloudwatch describe-alarms --region "$REGION" --query "MetricAlarms[?starts_with(AlarmName, '$ALARM_PREFIX')].{Name:AlarmName,State:StateValue}" --output table)
    echo ""
    print_status "INFO" "Alarm states:"
    echo "$ALARM_STATES"
else
    print_status "ERROR" "No CloudWatch alarms found"
fi

echo ""
print_status "INFO" "Monitoring health check completed"

# Generate dashboard URL
DASHBOARD_URL="https://${REGION}.console.aws.amazon.com/cloudwatch/home?region=${REGION}#dashboards:name=${DASHBOARD_NAME}"
print_status "INFO" "Dashboard URL: $DASHBOARD_URL"