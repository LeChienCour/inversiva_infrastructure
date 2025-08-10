# Cost Monitoring and Reporting Script (PowerShell)
# This script provides utilities for monitoring AWS costs and generating reports

param(
    [Parameter(Position=0)]
    [ValidateSet("report", "breakdown", "trends", "budget", "optimize", "help")]
    [string]$Command,
    
    [Alias("d")]
    [int]$Days = 30,
    
    [Alias("g")]
    [ValidateSet("DAILY", "MONTHLY")]
    [string]$Granularity = "DAILY",
    
    [Alias("m")]
    [ValidateSet("BlendedCost", "UnblendedCost")]
    [string]$Metrics = "BlendedCost",
    
    [Alias("e")]
    [string]$Environment = "",
    
    [Alias("s")]
    [string]$Service = "",
    
    [Alias("f")]
    [ValidateSet("table", "json", "csv")]
    [string]$Format = "table",
    
    [Alias("o")]
    [string]$OutputFile = "",
    
    [Alias("v")]
    [switch]$Verbose
)

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

# Logging functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Help function
function Show-Help {
    @"
Cost Monitoring and Reporting Script

USAGE:
    .\cost-monitor.ps1 [COMMAND] [OPTIONS]

COMMANDS:
    report      Generate cost report for the project
    breakdown   Show cost breakdown by service
    trends      Show cost trends over time
    budget      Check budget status and alerts
    optimize    Show cost optimization recommendations
    help        Show this help message

OPTIONS:
    -Days, -d DAYS          Number of days to analyze [default: 30]
    -Granularity, -g GRAN   Granularity (DAILY/MONTHLY) [default: DAILY]
    -Metrics, -m METRICS    Cost metrics (BlendedCost/UnblendedCost) [default: BlendedCost]
    -Environment, -e ENV    Filter by environment (dev/prod)
    -Service, -s SERVICE    Filter by AWS service
    -Format, -f FORMAT      Output format (table/json/csv) [default: table]
    -OutputFile, -o FILE    Output file path
    -Verbose, -v           Verbose output

EXAMPLES:
    # Generate monthly cost report
    .\cost-monitor.ps1 report -d 30 -g MONTHLY
    
    # Show cost breakdown by service for dev environment
    .\cost-monitor.ps1 breakdown -e dev -d 7
    
    # Show cost trends for the last 90 days
    .\cost-monitor.ps1 trends -d 90
    
    # Check budget status
    .\cost-monitor.ps1 budget
    
    # Get cost optimization recommendations
    .\cost-monitor.ps1 optimize -e prod -v

"@
}

# Check if AWS CLI is configured
function Test-AwsCli {
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        Write-Error "AWS CLI is not installed or not in PATH"
        return $false
    }
    
    try {
        aws sts get-caller-identity | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "AWS CLI is not configured or credentials are invalid"
            Write-Info "Run 'aws configure' to set up your credentials"
            return $false
        }
    }
    catch {
        Write-Error "AWS CLI is not configured or credentials are invalid"
        Write-Info "Run 'aws configure' to set up your credentials"
        return $false
    }
    
    Write-Info "AWS CLI is configured and ready"
    return $true
}

# Get project tags for filtering
function Get-ProjectTags {
    param([string]$Environment)
    
    $Tags = @()
    
    # Try to get project name from terragrunt config
    $TerragruntConfig = Join-Path $ProjectRoot "terragrunt.hcl"
    if (Test-Path $TerragruntConfig) {
        $Content = Get-Content $TerragruntConfig -Raw
        if ($Content -match 'project_name\s*=\s*"([^"]*)"') {
            $ProjectName = $Matches[1]
            $Tags += "Key=Project,Values=$ProjectName"
        }
    }
    
    # Add environment filter if specified
    if ($Environment) {
        $Tags += "Key=Environment,Values=$Environment"
    }
    
    return $Tags -join " "
}

# Generate cost report
function New-CostReport {
    param(
        [int]$Days,
        [string]$Granularity,
        [string]$Metrics,
        [string]$Environment,
        [string]$Format,
        [string]$OutputFile,
        [bool]$Verbose
    )
    
    Write-Info "Generating cost report..."
    Write-Info "Period: Last $Days days"
    Write-Info "Granularity: $Granularity"
    Write-Info "Metrics: $Metrics"
    
    # Calculate date range
    $StartDate = (Get-Date).AddDays(-$Days).ToString("yyyy-MM-dd")
    $EndDate = (Get-Date).ToString("yyyy-MM-dd")
    
    Write-Info "Date range: $StartDate to $EndDate"
    
    # Build AWS CLI command
    $CmdArgs = @(
        "ce", "get-cost-and-usage",
        "--time-period", "Start=$StartDate,End=$EndDate",
        "--granularity", $Granularity,
        "--metrics", $Metrics,
        "--group-by", "Type=DIMENSION,Key=SERVICE"
    )
    
    # Add filters if specified
    $Tags = Get-ProjectTags $Environment
    if ($Tags) {
        $CmdArgs += "--filter"
        $CmdArgs += "Dimensions={Key=TAG,Values=[$Tags]}"
    }
    
    if ($Verbose) {
        Write-Info "Executing: aws $($CmdArgs -join ' ')"
    }
    
    # Execute command and process output
    try {
        $Result = & aws @CmdArgs 2>$null | ConvertFrom-Json
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to retrieve cost data"
            return $false
        }
        
        # Process and display results
        switch ($Format) {
            "json" {
                $JsonOutput = $Result | ConvertTo-Json -Depth 10
                if ($OutputFile) {
                    $JsonOutput | Out-File -FilePath $OutputFile -Encoding UTF8
                    Write-Success "Cost report saved to: $OutputFile"
                }
                else {
                    Write-Output $JsonOutput
                }
            }
            "csv" {
                $CsvData = @()
                $CsvData += "Date,Service,Amount,Unit"
                
                foreach ($TimeResult in $Result.ResultsByTime) {
                    $Date = $TimeResult.TimePeriod.Start
                    foreach ($Group in $TimeResult.Groups) {
                        $Service = $Group.Keys[0]
                        $Amount = $Group.Metrics.$Metrics.Amount
                        $Unit = $Group.Metrics.$Metrics.Unit
                        $CsvData += "$Date,$Service,$Amount,$Unit"
                    }
                }
                
                if ($OutputFile) {
                    $CsvData | Out-File -FilePath $OutputFile -Encoding UTF8
                    Write-Success "Cost report saved to: $OutputFile"
                }
                else {
                    $CsvData | Write-Output
                }
            }
            default {
                # Table format
                Show-CostTable $Result $Verbose
            }
        }
        
        return $true
    }
    catch {
        Write-Error "Failed to retrieve cost data: $($_.Exception.Message)"
        return $false
    }
}

# Display cost data in table format
function Show-CostTable {
    param($Result, [bool]$Verbose)
    
    Write-Host ""
    Write-Host "Cost Report Summary:" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    
    # Calculate total cost
    $TotalCost = 0
    foreach ($TimeResult in $Result.ResultsByTime) {
        foreach ($Group in $TimeResult.Groups) {
            $TotalCost += [double]$Group.Metrics.BlendedCost.Amount
        }
    }
    
    Write-Host "Total Cost: `$$([math]::Round($TotalCost, 2))"
    Write-Host ""
    
    # Show top services by cost
    Write-Host "Top Services by Cost:" -ForegroundColor Yellow
    Write-Host "--------------------" -ForegroundColor Yellow
    
    $ServiceCosts = @{}
    foreach ($TimeResult in $Result.ResultsByTime) {
        foreach ($Group in $TimeResult.Groups) {
            $Service = $Group.Keys[0]
            $Cost = [double]$Group.Metrics.BlendedCost.Amount
            
            if ($ServiceCosts.ContainsKey($Service)) {
                $ServiceCosts[$Service] += $Cost
            }
            else {
                $ServiceCosts[$Service] = $Cost
            }
        }
    }
    
    $ServiceCosts.GetEnumerator() | 
        Sort-Object Value -Descending | 
        Select-Object -First 10 | 
        ForEach-Object {
            Write-Host "$($_.Key): `$$([math]::Round($_.Value, 2))"
        }
    
    if ($Verbose) {
        Write-Host ""
        Write-Host "Daily Breakdown:" -ForegroundColor Yellow
        Write-Host "---------------" -ForegroundColor Yellow
        
        foreach ($TimeResult in $Result.ResultsByTime) {
            $DailyTotal = 0
            foreach ($Group in $TimeResult.Groups) {
                $DailyTotal += [double]$Group.Metrics.BlendedCost.Amount
            }
            Write-Host "$($TimeResult.TimePeriod.Start): `$$([math]::Round($DailyTotal, 2))"
        }
    }
}

# Show cost breakdown by service
function Show-CostBreakdown {
    param(
        [int]$Days,
        [string]$Environment,
        [string]$Service,
        [bool]$Verbose
    )
    
    Write-Info "Generating cost breakdown..."
    
    return New-CostReport $Days "DAILY" "BlendedCost" $Environment "table" "" $Verbose
}

# Show cost trends
function Show-CostTrends {
    param([int]$Days, [bool]$Verbose)
    
    Write-Info "Analyzing cost trends for the last $Days days..."
    
    # Get daily costs
    $StartDate = (Get-Date).AddDays(-$Days).ToString("yyyy-MM-dd")
    $EndDate = (Get-Date).ToString("yyyy-MM-dd")
    
    try {
        $Result = aws ce get-cost-and-usage `
            --time-period "Start=$StartDate,End=$EndDate" `
            --granularity DAILY `
            --metrics BlendedCost 2>$null | ConvertFrom-Json
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to retrieve cost trend data"
            return $false
        }
        
        Write-Host ""
        Write-Host "Cost Trends Analysis:" -ForegroundColor Cyan
        Write-Host "====================" -ForegroundColor Cyan
        
        # Calculate average daily cost
        $DailyCosts = @()
        foreach ($TimeResult in $Result.ResultsByTime) {
            $DailyCosts += [double]$TimeResult.Total.BlendedCost.Amount
        }
        
        $AvgCost = ($DailyCosts | Measure-Object -Average).Average
        Write-Host "Average Daily Cost: `$$([math]::Round($AvgCost, 2))"
        
        # Show trend direction
        $FirstWeekCosts = $DailyCosts[0..6]
        $LastWeekCosts = $DailyCosts[-7..-1]
        
        $FirstWeekAvg = ($FirstWeekCosts | Measure-Object -Average).Average
        $LastWeekAvg = ($LastWeekCosts | Measure-Object -Average).Average
        
        if ($LastWeekAvg -gt $FirstWeekAvg) {
            Write-Host "Trend: INCREASING (↗)" -ForegroundColor Red
        }
        elseif ($LastWeekAvg -lt $FirstWeekAvg) {
            Write-Host "Trend: DECREASING (↘)" -ForegroundColor Green
        }
        else {
            Write-Host "Trend: STABLE (→)" -ForegroundColor Yellow
        }
        
        if ($Verbose) {
            Write-Host ""
            Write-Host "Daily Costs:" -ForegroundColor Yellow
            Write-Host "-----------" -ForegroundColor Yellow
            
            for ($i = 0; $i -lt $Result.ResultsByTime.Count; $i++) {
                $Date = $Result.ResultsByTime[$i].TimePeriod.Start
                $Cost = [double]$Result.ResultsByTime[$i].Total.BlendedCost.Amount
                Write-Host "$Date`: `$$([math]::Round($Cost, 2))"
            }
        }
        
        return $true
    }
    catch {
        Write-Error "Failed to retrieve cost trend data: $($_.Exception.Message)"
        return $false
    }
}

# Check budget status
function Test-BudgetStatus {
    param([bool]$Verbose)
    
    Write-Info "Checking budget status..."
    
    try {
        $AccountId = aws sts get-caller-identity --query Account --output text
        $Budgets = aws budgets describe-budgets --account-id $AccountId 2>$null | ConvertFrom-Json
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Could not retrieve budget information"
            Write-Info "You may need to create budgets first or check permissions"
            return $false
        }
        
        if ($Budgets.Budgets.Count -eq 0) {
            Write-Warning "No budgets configured"
            Write-Info "Consider creating budgets to monitor costs"
        }
        else {
            Write-Host ""
            Write-Host "Budget Status:" -ForegroundColor Cyan
            Write-Host "=============" -ForegroundColor Cyan
            
            foreach ($Budget in $Budgets.Budgets) {
                Write-Host "Budget: $($Budget.BudgetName)" -ForegroundColor Yellow
                Write-Host "  Limit: `$$($Budget.BudgetLimit.Amount) $($Budget.BudgetLimit.Unit)"
                Write-Host "  Type: $($Budget.BudgetType)"
                $EndPeriod = if ($Budget.TimePeriod.End) { $Budget.TimePeriod.End } else { "Ongoing" }
                Write-Host "  Time Period: $($Budget.TimePeriod.Start) to $EndPeriod"
                Write-Host ""
            }
        }
        
        return $true
    }
    catch {
        Write-Error "Failed to retrieve budget information: $($_.Exception.Message)"
        return $false
    }
}

# Show cost optimization recommendations
function Show-OptimizationRecommendations {
    param([string]$Environment, [bool]$Verbose)
    
    Write-Info "Generating cost optimization recommendations..."
    
    Write-Host ""
    Write-Host "Cost Optimization Recommendations:" -ForegroundColor Cyan
    Write-Host "==================================" -ForegroundColor Cyan
    
    # Check for unused resources (simplified check)
    Write-Host "1. Resource Utilization Analysis:" -ForegroundColor Yellow
    Write-Host "   - Review CloudFront cache hit ratios"
    Write-Host "   - Check S3 storage class optimization"
    Write-Host "   - Monitor Cognito active users"
    Write-Host ""
    
    # Environment-specific recommendations
    if ($Environment -eq "dev") {
        Write-Host "2. Development Environment Optimizations:" -ForegroundColor Yellow
        Write-Host "   - Use S3 Standard-IA for non-critical data"
        Write-Host "   - Consider CloudFront PriceClass_100"
        Write-Host "   - Implement lifecycle policies for temporary data"
        Write-Host ""
    }
    elseif ($Environment -eq "prod") {
        Write-Host "2. Production Environment Optimizations:" -ForegroundColor Yellow
        Write-Host "   - Monitor CloudFront cache performance"
        Write-Host "   - Review S3 access patterns for storage class optimization"
        Write-Host "   - Consider Reserved Capacity for predictable workloads"
        Write-Host ""
    }
    
    Write-Host "3. General Recommendations:" -ForegroundColor Yellow
    Write-Host "   - Enable detailed billing and cost allocation tags"
    Write-Host "   - Set up cost alerts and budgets"
    Write-Host "   - Regular review of AWS Cost Explorer"
    Write-Host "   - Consider AWS Cost Anomaly Detection"
    Write-Host ""
    
    # Get actual recommendations from AWS if available
    if ($Verbose) {
        Write-Info "Checking for AWS Cost Explorer recommendations..."
        
        try {
            $Rightsizing = aws ce get-rightsizing-recommendation --service EC2-Instance 2>$null | ConvertFrom-Json
            
            if ($LASTEXITCODE -eq 0 -and $Rightsizing.RightsizingRecommendations.Count -gt 0) {
                Write-Host "4. AWS Rightsizing Recommendations:" -ForegroundColor Yellow
                foreach ($Rec in $Rightsizing.RightsizingRecommendations) {
                    Write-Host "   - $($Rec.CurrentInstance.ResourceId): $($Rec.RightsizingType)"
                }
                Write-Host ""
            }
        }
        catch {
            # Rightsizing recommendations may not be available for all services
        }
    }
}

# Main execution
function Main {
    # Show help if no command provided
    if (-not $Command) {
        Show-Help
        return
    }
    
    # Check AWS CLI
    if (-not (Test-AwsCli)) {
        exit 1
    }
    
    # Execute command
    switch ($Command) {
        "report" {
            if (-not (New-CostReport $Days $Granularity $Metrics $Environment $Format $OutputFile $Verbose.IsPresent)) {
                exit 1
            }
        }
        "breakdown" {
            if (-not (Show-CostBreakdown $Days $Environment $Service $Verbose.IsPresent)) {
                exit 1
            }
        }
        "trends" {
            if (-not (Show-CostTrends $Days $Verbose.IsPresent)) {
                exit 1
            }
        }
        "budget" {
            if (-not (Test-BudgetStatus $Verbose.IsPresent)) {
                exit 1
            }
        }
        "optimize" {
            Show-OptimizationRecommendations $Environment $Verbose.IsPresent
        }
        "help" {
            Show-Help
        }
        default {
            Write-Error "Unknown command: $Command"
            Show-Help
            exit 1
        }
    }
}

# Run main function
Main