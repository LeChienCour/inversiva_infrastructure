# Security Exception Management Script (PowerShell)
# This script helps manage Checkov security exceptions and baseline updates

param(
    [Parameter(Position=0)]
    [ValidateSet("list", "add", "remove", "review", "update-baseline", "validate", "report", "help")]
    [string]$Command = "help",
    
    [string]$CheckId,
    [string]$Environment,
    [string]$Resource,
    [string]$Justification,
    [string]$ApprovedBy,
    [string]$ReviewDate
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$BaselineFile = Join-Path $ProjectRoot ".checkov.baseline"
$ConfigFile = Join-Path $ProjectRoot ".checkov.yml"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to show usage
function Show-Usage {
    Write-ColorOutput "Security Exception Management Script" "Cyan"
    Write-Host ""
    Write-ColorOutput "Usage: .\manage-security-exceptions.ps1 [COMMAND] [OPTIONS]" "Yellow"
    Write-Host ""
    Write-ColorOutput "Commands:" "Green"
    Write-Host "    list                    List all current security exceptions"
    Write-Host "    add                     Add a new security exception"
    Write-Host "    remove                  Remove a security exception"
    Write-Host "    review                  Review exceptions that need renewal"
    Write-Host "    update-baseline         Update baseline from latest scan results"
    Write-Host "    validate                Validate current exceptions and baseline"
    Write-Host "    report                  Generate security exceptions report"
    Write-Host ""
    Write-ColorOutput "Parameters:" "Green"
    Write-Host "    -CheckId ID            Specific Checkov check ID (e.g., CKV_AWS_18)"
    Write-Host "    -Environment ENV       Environment (dev, prod, all)"
    Write-Host "    -Resource RESOURCE     Specific resource pattern"
    Write-Host "    -Justification TEXT    Justification for the exception"
    Write-Host "    -ApprovedBy NAME       Name of person approving the exception"
    Write-Host "    -ReviewDate DATE       Date when exception should be reviewed (YYYY-MM-DD)"
    Write-Host ""
    Write-ColorOutput "Examples:" "Green"
    Write-Host "    .\manage-security-exceptions.ps1 list"
    Write-Host "    .\manage-security-exceptions.ps1 add -CheckId CKV_AWS_18 -Environment dev -Justification 'Cost optimization' -ApprovedBy 'Security Team'"
    Write-Host "    .\manage-security-exceptions.ps1 remove -CheckId CKV_AWS_18 -Environment dev"
    Write-Host "    .\manage-security-exceptions.ps1 review"
    Write-Host "    .\manage-security-exceptions.ps1 report"
}

# Function to list current exceptions
function List-Exceptions {
    Write-ColorOutput "Current Security Exceptions:" "Cyan"
    Write-Host ""
    
    if (-not (Test-Path $BaselineFile)) {
        Write-ColorOutput "No baseline file found at $BaselineFile" "Yellow"
        return
    }
    
    try {
        $baseline = Get-Content $BaselineFile | ConvertFrom-Json
        
        if ($baseline.approved_exceptions) {
            foreach ($exception in $baseline.approved_exceptions.PSObject.Properties) {
                $checkId = $exception.Name
                $details = $exception.Value
                
                Write-ColorOutput "Check ID: $checkId" "White"
                Write-Host "Description: $($details.description)"
                Write-Host "Justification: $($details.justification)"
                Write-Host "Approved by: $($details.approved_by)"
                Write-Host "Approval date: $($details.approval_date)"
                Write-Host "Review date: $($details.review_date)"
                Write-Host "Environments: $($details.environments -join ', ')"
                Write-Host "Resources: $($details.resources -join ', ')"
                Write-Host "---"
            }
        } else {
            Write-ColorOutput "No approved exceptions found" "Yellow"
        }
    }
    catch {
        Write-ColorOutput "Error parsing baseline file: $($_.Exception.Message)" "Red"
    }
}

# Function to add new exception
function Add-Exception {
    # Validate required parameters
    if (-not $CheckId -or -not $Environment -or -not $Justification -or -not $ApprovedBy) {
        Write-ColorOutput "Missing required parameters. Need: -CheckId, -Environment, -Justification, -ApprovedBy" "Red"
        return
    }
    
    # Set default review date if not provided (6 months from now)
    if (-not $ReviewDate) {
        $ReviewDate = (Get-Date).AddMonths(6).ToString("yyyy-MM-dd")
    }
    
    # Set default resource if not provided
    if (-not $Resource) {
        $Resource = "*"
    }
    
    Write-ColorOutput "Adding security exception:" "Cyan"
    Write-Host "Check ID: $CheckId"
    Write-Host "Environment: $Environment"
    Write-Host "Resource: $Resource"
    Write-Host "Justification: $Justification"
    Write-Host "Approved by: $ApprovedBy"
    Write-Host "Review date: $ReviewDate"
    Write-Host ""
    
    # Confirm addition
    $confirmation = Read-Host "Add this exception? (y/N)"
    if ($confirmation -ne "y" -and $confirmation -ne "Y") {
        Write-ColorOutput "Exception not added" "Yellow"
        return
    }
    
    # Create backup of baseline file
    if (Test-Path $BaselineFile) {
        $backupFile = "$BaselineFile.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $BaselineFile $backupFile
    }
    
    # Load or create baseline
    $baseline = @{
        version = "1.0"
        description = "Checkov baseline file for approved security exceptions"
        baseline_date = (Get-Date -Format "yyyy-MM-dd")
        approved_exceptions = @{}
        soft_fail_exceptions = @{}
    }
    
    if (Test-Path $BaselineFile) {
        try {
            $baseline = Get-Content $BaselineFile | ConvertFrom-Json -AsHashtable
        }
        catch {
            Write-ColorOutput "Error reading existing baseline, creating new one" "Yellow"
        }
    }
    
    # Add the new exception
    $newException = @{
        description = "Security exception for $CheckId"
        justification = $Justification
        approved_by = $ApprovedBy
        approval_date = (Get-Date -Format "yyyy-MM-dd")
        review_date = $ReviewDate
        environments = @($Environment)
        resources = @($Resource)
    }
    
    $baseline.approved_exceptions[$CheckId] = $newException
    
    # Save updated baseline
    $baseline | ConvertTo-Json -Depth 10 | Set-Content $BaselineFile
    
    Write-ColorOutput "Exception added successfully!" "Green"
}

# Function to remove exception
function Remove-Exception {
    if (-not $CheckId) {
        Write-ColorOutput "Missing required parameter: -CheckId" "Red"
        return
    }
    
    if (-not (Test-Path $BaselineFile)) {
        Write-ColorOutput "Baseline file not found" "Red"
        return
    }
    
    # Create backup
    $backupFile = "$BaselineFile.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $BaselineFile $backupFile
    
    try {
        $baseline = Get-Content $BaselineFile | ConvertFrom-Json -AsHashtable
        
        if ($baseline.approved_exceptions.ContainsKey($CheckId)) {
            $baseline.approved_exceptions.Remove($CheckId)
            $baseline | ConvertTo-Json -Depth 10 | Set-Content $BaselineFile
            Write-ColorOutput "Exception removed: $CheckId" "Green"
        } else {
            Write-ColorOutput "Exception not found: $CheckId" "Yellow"
        }
    }
    catch {
        Write-ColorOutput "Error processing baseline file: $($_.Exception.Message)" "Red"
    }
}

# Function to review exceptions needing renewal
function Review-Exceptions {
    Write-ColorOutput "Reviewing exceptions that need renewal:" "Cyan"
    Write-Host ""
    
    if (-not (Test-Path $BaselineFile)) {
        Write-ColorOutput "No baseline file found" "Yellow"
        return
    }
    
    try {
        $baseline = Get-Content $BaselineFile | ConvertFrom-Json
        $currentDate = Get-Date
        $warningDate = $currentDate.AddDays(30)
        
        $needsReview = $false
        
        foreach ($exception in $baseline.approved_exceptions.PSObject.Properties) {
            $checkId = $exception.Name
            $details = $exception.Value
            $reviewDate = [DateTime]::Parse($details.review_date)
            
            if ($reviewDate -le $warningDate) {
                $needsReview = $true
                Write-ColorOutput "⚠️  Check ID: $checkId" "Yellow"
                Write-Host "   Review Date: $($details.review_date)"
                Write-Host "   Description: $($details.description)"
                Write-Host "   Approved by: $($details.approved_by)"
                Write-Host "   ---"
            }
        }
        
        if (-not $needsReview) {
            Write-ColorOutput "No exceptions need review at this time" "Green"
        }
    }
    catch {
        Write-ColorOutput "Error parsing baseline file: $($_.Exception.Message)" "Red"
    }
}

# Function to update baseline from scan results
function Update-Baseline {
    Write-ColorOutput "Updating baseline from latest scan results..." "Cyan"
    
    Push-Location $ProjectRoot
    
    try {
        Write-ColorOutput "Running Checkov scan to generate baseline..." "Yellow"
        
        # Run Checkov to generate current results
        $tempDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path $_ }
        
        & checkov --config-file .checkov.yml --directory . --output json --output-file-path $tempDir.FullName --create-baseline
        
        $resultsFile = Join-Path $tempDir.FullName "results_json.json"
        if (Test-Path $resultsFile) {
            Write-ColorOutput "Baseline updated from scan results" "Green"
        } else {
            Write-ColorOutput "Failed to generate scan results" "Red"
        }
        
        Remove-Item $tempDir -Recurse -Force
    }
    catch {
        Write-ColorOutput "Error updating baseline: $($_.Exception.Message)" "Red"
    }
    finally {
        Pop-Location
    }
}

# Function to validate current exceptions
function Validate-Exceptions {
    Write-ColorOutput "Validating current security exceptions..." "Cyan"
    
    if (-not (Test-Path $BaselineFile)) {
        Write-ColorOutput "Baseline file not found" "Red"
        return $false
    }
    
    try {
        $baseline = Get-Content $BaselineFile | ConvertFrom-Json
        $validationErrors = 0
        
        foreach ($exception in $baseline.approved_exceptions.PSObject.Properties) {
            $checkId = $exception.Name
            $details = $exception.Value
            
            if (-not $details.description -or -not $details.justification -or -not $details.approved_by) {
                Write-ColorOutput "Incomplete exception for $checkId" "Red"
                $validationErrors++
            }
        }
        
        if ($validationErrors -eq 0) {
            Write-ColorOutput "All exceptions are valid" "Green"
            return $true
        } else {
            Write-ColorOutput "Found $validationErrors validation errors" "Red"
            return $false
        }
    }
    catch {
        Write-ColorOutput "Invalid JSON in baseline file: $($_.Exception.Message)" "Red"
        return $false
    }
}

# Function to generate security exceptions report
function Generate-Report {
    Write-ColorOutput "Generating security exceptions report..." "Cyan"
    
    $reportFile = Join-Path $ProjectRoot "security-exceptions-report.md"
    $currentDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    $reportContent = @"
# Security Exceptions Report

**Generated**: $currentDate
**Baseline File**: .checkov.baseline
**Configuration**: .checkov.yml

## Summary

"@
    
    if (Test-Path $BaselineFile) {
        try {
            $baseline = Get-Content $BaselineFile | ConvertFrom-Json
            $totalExceptions = ($baseline.approved_exceptions.PSObject.Properties | Measure-Object).Count
            $softFailExceptions = if ($baseline.soft_fail_exceptions) { ($baseline.soft_fail_exceptions.PSObject.Properties | Measure-Object).Count } else { 0 }
            
            $reportContent += @"

- **Total Approved Exceptions**: $totalExceptions
- **Soft Fail Exceptions**: $softFailExceptions

## Approved Exceptions

"@
            
            foreach ($exception in $baseline.approved_exceptions.PSObject.Properties) {
                $checkId = $exception.Name
                $details = $exception.Value
                
                $reportContent += @"

### $checkId

**Description**: $($details.description)
**Justification**: $($details.justification)
**Approved By**: $($details.approved_by)
**Approval Date**: $($details.approval_date)
**Review Date**: $($details.review_date)
**Environments**: $($details.environments -join ', ')
**Resources**: $($details.resources -join ', ')

---
"@
            }
            
            $reportContent += @"

## Soft Fail Exceptions

"@
            
            if ($baseline.soft_fail_exceptions) {
                foreach ($exception in $baseline.soft_fail_exceptions.PSObject.Properties) {
                    $checkId = $exception.Name
                    $details = $exception.Value
                    
                    $reportContent += @"

### $checkId

**Description**: $($details.description)
**Justification**: $($details.justification)
**Environments**: $($details.environments -join ', ')

---
"@
                }
            } else {
                $reportContent += "`nNo soft fail exceptions`n"
            }
        }
        catch {
            $reportContent += "`n- **Error reading baseline file**`n"
        }
    } else {
        $reportContent += "`n- **No baseline file found**`n"
    }
    
    $nextReviewDate = (Get-Date).AddMonths(3).ToString("yyyy-MM-dd")
    
    $reportContent += @"

## Recommendations

1. Review all exceptions quarterly
2. Update justifications when business requirements change
3. Remove exceptions that are no longer needed
4. Ensure all exceptions have proper approval documentation
5. Monitor for new security checks that might need exceptions

## Next Review Date

$nextReviewDate

"@
    
    Set-Content -Path $reportFile -Value $reportContent
    Write-ColorOutput "Report generated: $reportFile" "Green"
}

# Main script logic
switch ($Command) {
    "list" { List-Exceptions }
    "add" { Add-Exception }
    "remove" { Remove-Exception }
    "review" { Review-Exceptions }
    "update-baseline" { Update-Baseline }
    "validate" { Validate-Exceptions }
    "report" { Generate-Report }
    default { Show-Usage }
}