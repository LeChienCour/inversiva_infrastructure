# Environment Cleanup and Resource Management Script (PowerShell)
# This script provides utilities for cleaning up and managing AWS resources

param(
    [Parameter(Position=0)]
    [ValidateSet("destroy", "cleanup", "list", "validate", "backup", "help")]
    [string]$Command,
    
    [Alias("e")]
    [string]$Environment = "dev",
    
    [Alias("r")]
    [ValidateSet("s3", "cognito", "cloudfront", "all")]
    [string]$ResourceType = "all",
    
    [Alias("f")]
    [switch]$Force,
    
    [Alias("b")]
    [switch]$Backup,
    
    [Alias("d")]
    [switch]$DryRun,
    
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
Environment Cleanup and Resource Management Script

USAGE:
    .\env-cleanup.ps1 [COMMAND] [OPTIONS]

COMMANDS:
    destroy     Destroy all resources in an environment
    cleanup     Clean up specific resource types
    list        List all resources in an environment
    validate    Validate resource state and configuration
    backup      Backup important data before cleanup
    help        Show this help message

OPTIONS:
    -Environment, -e ENV    Environment to manage (dev/prod) [default: dev]
    -ResourceType, -r TYPE  Resource type to manage (s3/cognito/cloudfront/all)
    -Force, -f             Force operation without confirmation
    -Backup, -b            Create backup before cleanup
    -DryRun, -d            Show what would be done without executing
    -Verbose, -v           Verbose output

EXAMPLES:
    # List all resources in dev environment
    .\env-cleanup.ps1 list -e dev
    
    # Clean up S3 buckets in dev environment with backup
    .\env-cleanup.ps1 cleanup -e dev -r s3 -b
    
    # Destroy entire dev environment (with confirmation)
    .\env-cleanup.ps1 destroy -e dev
    
    # Dry run of production cleanup
    .\env-cleanup.ps1 cleanup -e prod -r all -d
    
    # Validate resource state
    .\env-cleanup.ps1 validate -e dev -v

"@
}

# Check if required tools are available
function Test-Dependencies {
    $MissingTools = @()
    
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        $MissingTools += "aws"
    }
    
    if (-not (Get-Command terragrunt -ErrorAction SilentlyContinue)) {
        $MissingTools += "terragrunt"
    }
    
    if ($MissingTools.Count -gt 0) {
        Write-Error "Missing required tools: $($MissingTools -join ', ')"
        Write-Info "Please install the missing tools and try again"
        return $false
    }
    
    # Check AWS CLI configuration
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
    
    Write-Info "All dependencies are available"
    return $true
}

# Confirm dangerous operations
function Confirm-Operation {
    param(
        [string]$Operation,
        [string]$Environment,
        [bool]$Force
    )
    
    if ($Force) {
        return $true
    }
    
    Write-Host ""
    Write-Warning "You are about to $Operation in the '$Environment' environment"
    Write-Warning "This operation may be irreversible!"
    Write-Host ""
    
    $Confirmation = Read-Host "Are you sure you want to continue? (type 'yes' to confirm)"
    
    if ($Confirmation -ne "yes") {
        Write-Info "Operation cancelled by user"
        return $false
    }
    
    return $true
}

# Get environment path
function Get-EnvironmentPath {
    param([string]$Environment)
    
    $EnvPath = Join-Path $ProjectRoot "environments\$Environment"
    
    if (-not (Test-Path $EnvPath)) {
        Write-Error "Environment directory not found: $EnvPath"
        return $null
    }
    
    return $EnvPath
}

# List resources in environment
function Get-EnvironmentResources {
    param(
        [string]$Environment,
        [bool]$Verbose
    )
    
    Write-Info "Listing resources in '$Environment' environment..."
    
    $EnvPath = Get-EnvironmentPath $Environment
    if (-not $EnvPath) {
        return $false
    }
    
    Write-Host ""
    Write-Host "Environment: $Environment" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    
    # List Terragrunt modules
    $Modules = @()
    Get-ChildItem -Path $EnvPath -Directory | ForEach-Object {
        $TerragruntFile = Join-Path $_.FullName "terragrunt.hcl"
        if (Test-Path $TerragruntFile) {
            $Modules += $_.Name
        }
    }
    
    if ($Modules.Count -eq 0) {
        Write-Warning "No Terragrunt modules found in environment"
        return $true
    }
    
    Write-Host "Terragrunt Modules:" -ForegroundColor Yellow
    Write-Host "------------------" -ForegroundColor Yellow
    
    foreach ($Module in $Modules) {
        Write-Host "  - $Module"
        
        if ($Verbose) {
            # Get module outputs if available
            $ModulePath = Join-Path $EnvPath $Module
            Push-Location $ModulePath
            try {
                $Outputs = terragrunt output -json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($Outputs) {
                    $Outputs.PSObject.Properties | ForEach-Object {
                        Write-Host "    $($_.Name): $($_.Value.value)"
                    }
                }
            }
            catch {
                # Ignore errors getting outputs
            }
            finally {
                Pop-Location
            }
        }
    }
    
    Write-Host ""
    
    # List AWS resources if verbose
    if ($Verbose) {
        Write-Info "Checking AWS resources..."
        
        # S3 buckets
        try {
            $Buckets = aws s3api list-buckets --query "Buckets[?contains(Name, '$Environment')].Name" --output text 2>$null
            if ($LASTEXITCODE -eq 0 -and $Buckets) {
                Write-Host "S3 Buckets:" -ForegroundColor Yellow
                Write-Host "----------" -ForegroundColor Yellow
                $Buckets -split "`t" | ForEach-Object {
                    if ($_) { Write-Host "  - $_" }
                }
                Write-Host ""
            }
        }
        catch {
            # Ignore errors
        }
        
        # Cognito User Pools
        try {
            $UserPools = aws cognito-idp list-user-pools --max-results 60 --query "UserPools[?contains(Name, '$Environment')].Name" --output text 2>$null
            if ($LASTEXITCODE -eq 0 -and $UserPools) {
                Write-Host "Cognito User Pools:" -ForegroundColor Yellow
                Write-Host "------------------" -ForegroundColor Yellow
                $UserPools -split "`t" | ForEach-Object {
                    if ($_) { Write-Host "  - $_" }
                }
                Write-Host ""
            }
        }
        catch {
            # Ignore errors
        }
        
        # CloudFront Distributions
        try {
            $Distributions = aws cloudfront list-distributions --query "DistributionList.Items[?contains(Comment, '$Environment')].Id" --output text 2>$null
            if ($LASTEXITCODE -eq 0 -and $Distributions) {
                Write-Host "CloudFront Distributions:" -ForegroundColor Yellow
                Write-Host "------------------------" -ForegroundColor Yellow
                $Distributions -split "`t" | ForEach-Object {
                    if ($_) { Write-Host "  - $_" }
                }
                Write-Host ""
            }
        }
        catch {
            # Ignore errors
        }
    }
    
    return $true
}

# Validate resource state
function Test-ResourceState {
    param(
        [string]$Environment,
        [bool]$Verbose
    )
    
    Write-Info "Validating resources in '$Environment' environment..."
    
    $EnvPath = Get-EnvironmentPath $Environment
    if (-not $EnvPath) {
        return $false
    }
    
    $ValidationErrors = 0
    
    # Validate each Terragrunt module
    Get-ChildItem -Path $EnvPath -Directory | ForEach-Object {
        $TerragruntFile = Join-Path $_.FullName "terragrunt.hcl"
        if (Test-Path $TerragruntFile) {
            $ModuleName = $_.Name
            
            Write-Info "Validating module: $ModuleName"
            
            Push-Location $_.FullName
            try {
                # Run terragrunt validate
                terragrunt validate 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Module $ModuleName is valid"
                }
                else {
                    Write-Error "Validation failed for module: $ModuleName"
                    $ValidationErrors++
                    
                    if ($Verbose) {
                        terragrunt validate
                    }
                }
                
                # Check if state exists and is accessible
                terragrunt state list 2>$null | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "State not accessible for module: $ModuleName"
                }
            }
            finally {
                Pop-Location
            }
        }
    }
    
    if ($ValidationErrors -eq 0) {
        Write-Success "All modules passed validation"
        return $true
    }
    else {
        Write-Error "Found $ValidationErrors validation errors"
        return $false
    }
}

# Backup important data
function Backup-EnvironmentData {
    param(
        [string]$Environment,
        [bool]$Verbose
    )
    
    Write-Info "Creating backup for '$Environment' environment..."
    
    $BackupDir = Join-Path $ProjectRoot "backups\$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    
    # Backup Terraform state files
    Write-Info "Backing up Terraform state files..."
    $EnvPath = Get-EnvironmentPath $Environment
    
    Get-ChildItem -Path $EnvPath -Directory | ForEach-Object {
        $TerragruntFile = Join-Path $_.FullName "terragrunt.hcl"
        if (Test-Path $TerragruntFile) {
            $ModuleName = $_.Name
            
            Push-Location $_.FullName
            try {
                # Pull latest state
                $StateFile = Join-Path $BackupDir "$ModuleName-terraform.tfstate"
                terragrunt state pull > $StateFile 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Backed up state for module: $ModuleName"
                }
                else {
                    Write-Warning "Could not backup state for module: $ModuleName"
                }
            }
            finally {
                Pop-Location
            }
        }
    }
    
    # Backup S3 bucket contents (metadata only)
    Write-Info "Backing up S3 bucket metadata..."
    try {
        $Buckets = aws s3api list-buckets --query "Buckets[?contains(Name, '$Environment')].Name" --output text 2>$null
        if ($LASTEXITCODE -eq 0 -and $Buckets) {
            $Buckets -split "`t" | ForEach-Object {
                if ($_) {
                    $BucketName = $_
                    $ObjectsFile = Join-Path $BackupDir "$BucketName-objects.json"
                    aws s3api list-objects-v2 --bucket $BucketName > $ObjectsFile 2>$null
                    Write-Info "Backed up metadata for bucket: $BucketName"
                }
            }
        }
    }
    catch {
        # Ignore errors
    }
    
    # Create backup manifest
    $ManifestContent = @"
Backup created: $(Get-Date)
Environment: $Environment
Backup directory: $BackupDir

Contents:
- Terraform state files (*.tfstate)
- S3 bucket metadata (*-objects.json)

To restore:
1. Copy state files to appropriate module directories
2. Run 'terragrunt state push <state-file>' in each module
3. Verify with 'terragrunt plan'
"@
    
    $ManifestContent | Out-File -FilePath (Join-Path $BackupDir "manifest.txt") -Encoding UTF8
    
    Write-Success "Backup completed: $BackupDir"
    
    if ($Verbose) {
        Write-Host ""
        Write-Host "Backup contents:" -ForegroundColor Yellow
        Get-ChildItem -Path $BackupDir | ForEach-Object {
            Write-Host "  - $($_.Name)"
        }
    }
    
    return $true
}

# Clean up specific resource types
function Remove-EnvironmentResources {
    param(
        [string]$Environment,
        [string]$ResourceType,
        [bool]$Force,
        [bool]$Backup,
        [bool]$DryRun,
        [bool]$Verbose
    )
    
    if ($Backup) {
        if (-not (Backup-EnvironmentData $Environment $Verbose)) {
            return $false
        }
    }
    
    if (-not (Confirm-Operation "clean up $ResourceType resources" $Environment $Force)) {
        return $false
    }
    
    $EnvPath = Get-EnvironmentPath $Environment
    if (-not $EnvPath) {
        return $false
    }
    
    switch ($ResourceType) {
        "s3" {
            return Remove-S3Resources $Environment $DryRun $Verbose
        }
        "cognito" {
            return Remove-CognitoResources $Environment $DryRun $Verbose
        }
        "cloudfront" {
            return Remove-CloudFrontResources $Environment $DryRun $Verbose
        }
        "all" {
            return Remove-AllResources $Environment $DryRun $Verbose
        }
        default {
            Write-Error "Unknown resource type: $ResourceType"
            Write-Info "Supported types: s3, cognito, cloudfront, all"
            return $false
        }
    }
}

# Clean up S3 resources
function Remove-S3Resources {
    param(
        [string]$Environment,
        [bool]$DryRun,
        [bool]$Verbose
    )
    
    Write-Info "Cleaning up S3 resources for '$Environment' environment..."
    
    $EnvPath = Get-EnvironmentPath $Environment
    $ModuleTypes = @("s3-website", "s3-content")
    
    foreach ($ModuleType in $ModuleTypes) {
        $ModulePath = Join-Path $EnvPath $ModuleType
        
        if (Test-Path $ModulePath) {
            Write-Info "Processing module: $ModuleType"
            
            if ($DryRun) {
                Write-Info "[DRY RUN] Would destroy module: $ModuleType"
            }
            else {
                Push-Location $ModulePath
                try {
                    # Empty S3 buckets first
                    $BucketName = terragrunt output -raw bucket_name 2>$null
                    
                    if ($BucketName -and $LASTEXITCODE -eq 0) {
                        Write-Info "Emptying S3 bucket: $BucketName"
                        aws s3 rm "s3://$BucketName" --recursive 2>$null | Out-Null
                    }
                    
                    # Destroy the module
                    terragrunt destroy -auto-approve | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "Destroyed module: $ModuleType"
                    }
                    else {
                        Write-Error "Failed to destroy module: $ModuleType"
                    }
                }
                finally {
                    Pop-Location
                }
            }
        }
    }
    
    return $true
}

# Clean up Cognito resources
function Remove-CognitoResources {
    param(
        [string]$Environment,
        [bool]$DryRun,
        [bool]$Verbose
    )
    
    Write-Info "Cleaning up Cognito resources for '$Environment' environment..."
    
    $EnvPath = Get-EnvironmentPath $Environment
    $ModulePath = Join-Path $EnvPath "cognito"
    
    if (Test-Path $ModulePath) {
        if ($DryRun) {
            Write-Info "[DRY RUN] Would destroy Cognito module"
        }
        else {
            Push-Location $ModulePath
            try {
                terragrunt destroy -auto-approve | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Destroyed Cognito module"
                }
                else {
                    Write-Error "Failed to destroy Cognito module"
                }
            }
            finally {
                Pop-Location
            }
        }
    }
    else {
        Write-Warning "Cognito module not found"
    }
    
    return $true
}

# Clean up CloudFront resources
function Remove-CloudFrontResources {
    param(
        [string]$Environment,
        [bool]$DryRun,
        [bool]$Verbose
    )
    
    Write-Info "Cleaning up CloudFront resources for '$Environment' environment..."
    
    $EnvPath = Get-EnvironmentPath $Environment
    $ModulePath = Join-Path $EnvPath "cloudfront"
    
    if (Test-Path $ModulePath) {
        if ($DryRun) {
            Write-Info "[DRY RUN] Would destroy CloudFront module"
        }
        else {
            Push-Location $ModulePath
            try {
                terragrunt destroy -auto-approve | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Destroyed CloudFront module"
                }
                else {
                    Write-Error "Failed to destroy CloudFront module"
                }
            }
            finally {
                Pop-Location
            }
        }
    }
    else {
        Write-Warning "CloudFront module not found"
    }
    
    return $true
}

# Clean up all resources
function Remove-AllResources {
    param(
        [string]$Environment,
        [bool]$DryRun,
        [bool]$Verbose
    )
    
    Write-Info "Cleaning up ALL resources for '$Environment' environment..."
    
    # Destroy in reverse dependency order
    Remove-CloudFrontResources $Environment $DryRun $Verbose | Out-Null
    Remove-S3Resources $Environment $DryRun $Verbose | Out-Null
    Remove-CognitoResources $Environment $DryRun $Verbose | Out-Null
    
    return $true
}

# Destroy entire environment
function Remove-Environment {
    param(
        [string]$Environment,
        [bool]$Force,
        [bool]$Backup,
        [bool]$DryRun,
        [bool]$Verbose
    )
    
    if ($Backup) {
        if (-not (Backup-EnvironmentData $Environment $Verbose)) {
            return $false
        }
    }
    
    if (-not (Confirm-Operation "DESTROY the entire '$Environment' environment" $Environment $Force)) {
        return $false
    }
    
    $EnvPath = Get-EnvironmentPath $Environment
    if (-not $EnvPath) {
        return $false
    }
    
    if ($DryRun) {
        Write-Info "[DRY RUN] Would destroy entire '$Environment' environment"
        Get-EnvironmentResources $Environment $true | Out-Null
        return $true
    }
    
    Write-Info "Destroying entire '$Environment' environment..."
    
    # Use terragrunt run-all destroy for proper dependency handling
    Push-Location $EnvPath
    try {
        terragrunt run-all destroy -auto-approve | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Successfully destroyed '$Environment' environment"
            return $true
        }
        else {
            Write-Error "Failed to destroy '$Environment' environment"
            Write-Info "Some resources may still exist. Check manually and retry if needed."
            return $false
        }
    }
    finally {
        Pop-Location
    }
}

# Main execution
function Main {
    # Show help if no command provided
    if (-not $Command) {
        Show-Help
        return
    }
    
    # Check dependencies
    if (-not (Test-Dependencies)) {
        exit 1
    }
    
    # Execute command
    $Success = $true
    
    switch ($Command) {
        "destroy" {
            $Success = Remove-Environment $Environment $Force.IsPresent $Backup.IsPresent $DryRun.IsPresent $Verbose.IsPresent
        }
        "cleanup" {
            $Success = Remove-EnvironmentResources $Environment $ResourceType $Force.IsPresent $Backup.IsPresent $DryRun.IsPresent $Verbose.IsPresent
        }
        "list" {
            $Success = Get-EnvironmentResources $Environment $Verbose.IsPresent
        }
        "validate" {
            $Success = Test-ResourceState $Environment $Verbose.IsPresent
        }
        "backup" {
            $Success = Backup-EnvironmentData $Environment $Verbose.IsPresent
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
    
    if (-not $Success) {
        exit 1
    }
}

# Run main function
Main