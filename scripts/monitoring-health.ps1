# Monitoring Health Check Script (PowerShell)
# This script checks the health and status of monitoring infrastructure

param(
    [string]$Environment = "dev",
    [string]$ProjectName = "nextjs-infrastructure", 
    [string]$Region = "us-east-1",
    [switch]$Help
)

# Function to print colored output
function Write-Status {
    param(
        [string]$Status,
        [string]$Message
    )
    
    switch ($Status) {
        "SUCCESS" { Write-Host "✓ $Message" -ForegroundColor Green }
        "WARNING" { Write-Host "⚠ $Message" -ForegroundColor Yellow }
        "ERROR" { Write-Host "✗ $Message" -ForegroundColor Red }
        "INFO" { Write-Host "ℹ $Message" -ForegroundColor Blue }
    }
}

# Function to show usage
function Show-Usage {
    Write-Host "Usage: .\monitoring-health.ps1 [OPTIONS]"
    Write-Host "Options:"
    Write-Host "  -Environment    Environment (dev/prod) [default: dev]"
    Write-Host "  -ProjectName    Project name [default: nextjs-infrastructure]"
    Write-Host "  -Region         AWS region [default: us-east-1]"
    Write-Host "  -Help           Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\monitoring-health.ps1 -Environment prod -ProjectName my-app -Region us-west-2"
    Write-Host "  .\monitoring-health.ps1 -Environment dev -ProjectName nextjs-app"
}

if ($Help) {
    Show-Usage
    exit 0
}

# Validate environment
if ($Environment -notin @("dev", "prod")) {
    Write-Status "ERROR" "Environment must be 'dev' or 'prod'"
    exit 1
}

Write-Status "INFO" "Checking monitoring health for $ProjectName ($Environment) in $Region"
Write-Host ""

# Check AWS CLI availability
try {
    $null = Get-Command aws -ErrorAction Stop
} catch {
    Write-Status "ERROR" "AWS CLI is not installed or not in PATH"
    exit 1
}

# Check AWS credentials
try {
    $null = aws sts get-caller-identity 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "AWS credentials error"
    }
} catch {
    Write-Status "ERROR" "AWS credentials not configured or invalid"
    exit 1
}

Write-Status "SUCCESS" "AWS CLI and credentials are configured"

# Check SNS Topic
$SnsTopicName = "$ProjectName-$Environment-alerts"
Write-Status "INFO" "Checking SNS topic: $SnsTopicName"

$topicExists = aws sns list-topics --region $Region --query "Topics[?contains(TopicArn, '$SnsTopicName')]" --output text
if ($topicExists -and $topicExists.Contains($SnsTopicName)) {
    Write-Status "SUCCESS" "SNS topic exists"
    
    # Check subscriptions
    $topicArn = aws sns list-topics --region $Region --query "Topics[?contains(TopicArn, '$SnsTopicName')].TopicArn" --output text
    $subscriptionCount = aws sns list-subscriptions-by-topic --topic-arn $topicArn --region $Region --query 'length(Subscriptions)'
    
    if ([int]$subscriptionCount -gt 0) {
        Write-Status "SUCCESS" "SNS topic has $subscriptionCount subscription(s)"
    } else {
        Write-Status "WARNING" "SNS topic has no subscriptions"
    }
} else {
    Write-Status "ERROR" "SNS topic not found"
}

# Check CloudWatch Dashboard
$DashboardName = "$ProjectName-$Environment-infrastructure"
Write-Status "INFO" "Checking CloudWatch dashboard: $DashboardName"

$dashboardExists = aws cloudwatch list-dashboards --region $Region --query "DashboardEntries[?DashboardName=='$DashboardName']" --output text
if ($dashboardExists -and $dashboardExists.Contains($DashboardName)) {
    Write-Status "SUCCESS" "CloudWatch dashboard exists"
} else {
    Write-Status "ERROR" "CloudWatch dashboard not found"
}

# Check Budget
$BudgetName = "$ProjectName-$Environment-budget"
Write-Status "INFO" "Checking budget: $BudgetName"

$AccountId = aws sts get-caller-identity --query Account --output text
try {
    $null = aws budgets describe-budget --account-id $AccountId --budget-name $BudgetName 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Status "SUCCESS" "Budget exists"
        
        # Get budget utilization
        $budgetInfo = aws budgets describe-budget --account-id $AccountId --budget-name $BudgetName --query 'Budget.{Limit:BudgetLimit.Amount,Actual:CalculatedSpend.ActualSpend.Amount}' --output json | ConvertFrom-Json
        $limit = $budgetInfo.Limit
        $actual = if ($budgetInfo.Actual) { $budgetInfo.Actual } else { "0" }
        
        if ($actual -ne "null" -and $actual -ne "0") {
            $percentage = [math]::Round(([double]$actual * 100 / [double]$limit), 1)
            Write-Status "INFO" "Budget utilization: `$$actual/`$$limit ($percentage%)"
        } else {
            Write-Status "INFO" "Budget utilization: No spending data available yet"
        }
    } else {
        throw "Budget not found"
    }
} catch {
    Write-Status "ERROR" "Budget not found"
}

# Check CloudTrail (only for prod)
if ($Environment -eq "prod") {
    $TrailName = "$ProjectName-$Environment-security-trail"
    Write-Status "INFO" "Checking CloudTrail: $TrailName"
    
    $trailExists = aws cloudtrail describe-trails --region $Region --query "trailList[?Name=='$TrailName']" --output text
    if ($trailExists -and $trailExists.Contains($TrailName)) {
        Write-Status "SUCCESS" "CloudTrail exists"
        
        # Check if logging is enabled
        $loggingStatus = aws cloudtrail get-trail-status --name $TrailName --region $Region --query 'IsLogging' --output text
        if ($loggingStatus -eq "True") {
            Write-Status "SUCCESS" "CloudTrail logging is enabled"
        } else {
            Write-Status "WARNING" "CloudTrail logging is disabled"
        }
    } else {
        Write-Status "ERROR" "CloudTrail not found"
    }
} else {
    Write-Status "INFO" "CloudTrail disabled for development environment (cost optimization)"
}

# Check CloudWatch Alarms
Write-Status "INFO" "Checking CloudWatch alarms"

$AlarmPrefix = "$ProjectName-$Environment"
$alarmCount = aws cloudwatch describe-alarms --region $Region --query "MetricAlarms[?starts_with(AlarmName, '$AlarmPrefix')] | length(@)"

if ([int]$alarmCount -gt 0) {
    Write-Status "SUCCESS" "Found $alarmCount CloudWatch alarm(s)"
    
    # Check alarm states
    Write-Host ""
    Write-Status "INFO" "Alarm states:"
    aws cloudwatch describe-alarms --region $Region --query "MetricAlarms[?starts_with(AlarmName, '$AlarmPrefix')].{Name:AlarmName,State:StateValue}" --output table
} else {
    Write-Status "ERROR" "No CloudWatch alarms found"
}

Write-Host ""
Write-Status "INFO" "Monitoring health check completed"

# Generate dashboard URL
$DashboardUrl = "https://$Region.console.aws.amazon.com/cloudwatch/home?region=$Region#dashboards:name=$DashboardName"
Write-Status "INFO" "Dashboard URL: $DashboardUrl"