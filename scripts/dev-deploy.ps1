# Development Deployment Script (PowerShell)
# This script mimics the GitHub Actions workflow for local testing

param(
    [string]$Component = "all",
    [string]$Action = "plan",
    [switch]$SkipValidation = $false,
    [switch]$SkipSecurity = $false,
    [switch]$Help = $false
)

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$DevEnvDir = Join-Path $ProjectRoot "environments\dev"

# Function to show usage
function Show-Usage {
    Write-Host @"
Usage: .\dev-deploy.ps1 [OPTIONS]

Local development deployment script for Terraform Next.js infrastructure.

OPTIONS:
    -Component COMPONENT      Component to deploy (all, cognito, s3-website, s3-content, cloudfront, route53-acm)
    -Action ACTION           Action to perform (plan, apply, destroy)
    -SkipValidation         Skip Terraform validation
    -SkipSecurity          Skip security scanning
    -Help                  Show this help message

EXAMPLES:
    .\dev-deploy.ps1                                    # Plan all components
    .\dev-deploy.ps1 -Component cognito -Action apply   # Apply cognito component
    .\dev-deploy.ps1 -Component all -Action plan -SkipSecurity    # Plan all components, skip security scan
    .\dev-deploy.ps1 -Action destroy                    # Destroy all components

REQUIREMENTS:
    - Terraform >= 1.6.6
    - Terragrunt >= 0.55.1
    - AWS CLI configured with appropriate credentials
    - Checkov (optional, for security scanning)
"@
}

# Function to print colored output
function Write-Status {
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

# Function to check prerequisites
function Test-Prerequisites {
    Write-Status "Checking prerequisites..."
    
    # Check Terraform
    try {
        $terraformVersion = (terraform version -json | ConvertFrom-Json).terraform_version
        Write-Status "Terraform version: $terraformVersion"
    }
    catch {
        Write-Error "Terraform is not installed or not in PATH"
        exit 1
    }
    
    # Check Terragrunt
    try {
        $terragruntVersion = (terragrunt --version | Select-String -Pattern 'v[\d.]+').Matches[0].Value
        Write-Status "Terragrunt version: $terragruntVersion"
    }
    catch {
        Write-Error "Terragrunt is not installed or not in PATH"
        exit 1
    }
    
    # Check AWS CLI
    try {
        $awsIdentity = aws sts get-caller-identity | ConvertFrom-Json
        $awsAccount = $awsIdentity.Account
        $awsRegion = (aws configure get region) -or "us-east-1"
        Write-Status "AWS Account: $awsAccount, Region: $awsRegion"
    }
    catch {
        Write-Error "AWS CLI is not installed or AWS credentials not configured"
        exit 1
    }
    
    # Check Checkov (optional)
    if (-not $SkipSecurity) {
        try {
            checkov --version | Out-Null
        }
        catch {
            Write-Warning "Checkov not found, skipping security scan"
            $script:SkipSecurity = $true
        }
    }
    
    Write-Success "Prerequisites check completed"
}

# Function to validate Terraform configuration
function Test-TerraformConfiguration {
    if ($SkipValidation) {
        Write-Warning "Skipping Terraform validation"
        return
    }
    
    Write-Status "Validating Terraform configuration..."
    
    Push-Location $ProjectRoot
    
    try {
        # Validate each module
        $moduleDirectories = Get-ChildItem -Path "modules" -Recurse -Filter "*.tf" | 
                           ForEach-Object { $_.Directory.FullName } | 
                           Sort-Object -Unique
        
        foreach ($dir in $moduleDirectories) {
            Write-Status "Validating $dir"
            Push-Location $dir
            
            terraform init -backend=false | Out-Null
            $result = terraform validate
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Validation failed for $dir"
                exit 1
            }
            
            Pop-Location
        }
        
        # Validate Terragrunt configuration
        Push-Location $DevEnvDir
        $result = terragrunt validate-inputs --terragrunt-non-interactive
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Terragrunt validation failed"
            exit 1
        }
        
        Write-Success "Terraform validation completed"
    }
    finally {
        Pop-Location
    }
}

# Function to run security scan
function Invoke-SecurityScan {
    if ($SkipSecurity) {
        Write-Warning "Skipping security scan"
        return
    }
    
    Write-Status "Running security scan with Checkov..."
    
    Push-Location $ProjectRoot
    
    try {
        $result = checkov -d . --framework terraform --skip-check CKV_AWS_18,CKV_AWS_19 --quiet
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Security scan found issues, but continuing..."
        }
        
        Write-Success "Security scan completed"
    }
    finally {
        Pop-Location
    }
}

# Function to get component list
function Get-Components {
    if ($Component -eq "all") {
        return @("cognito", "s3-website", "s3-content", "route53-acm", "cloudfront")
    }
    else {
        return @($Component)
    }
}

# Function to plan components
function Invoke-PlanComponents {
    $components = Get-Components
    Write-Status "Planning components: $($components -join ', ')"
    
    Push-Location $DevEnvDir
    
    try {
        $hasChanges = $false
        
        foreach ($comp in $components) {
            $componentPath = Join-Path $DevEnvDir $comp
            if (Test-Path $componentPath) {
                Write-Status "Planning $comp..."
                Push-Location $componentPath
                
                try {
                    # Initialize
                    $result = terragrunt init --terragrunt-non-interactive
                    if ($LASTEXITCODE -ne 0) {
                        Write-Error "Failed to initialize $comp"
                        exit 1
                    }
                    
                    # Plan
                    $result = terragrunt plan -detailed-exitcode --terragrunt-non-interactive
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "No changes for $comp"
                    }
                    elseif ($LASTEXITCODE -eq 2) {
                        Write-Warning "Changes detected for $comp"
                        $hasChanges = $true
                    }
                    else {
                        Write-Error "Planning failed for $comp"
                        exit 1
                    }
                }
                finally {
                    Pop-Location
                }
            }
            else {
                Write-Warning "Component $comp not found, skipping..."
            }
        }
        
        if ($hasChanges) {
            Write-Warning "Changes detected in one or more components"
            return 2
        }
        else {
            Write-Success "No changes detected in any component"
            return 0
        }
    }
    finally {
        Pop-Location
    }
}

# Function to apply components
function Invoke-ApplyComponents {
    $components = Get-Components
    Write-Status "Applying components: $($components -join ', ')"
    
    Push-Location $DevEnvDir
    
    try {
        foreach ($comp in $components) {
            $componentPath = Join-Path $DevEnvDir $comp
            if (Test-Path $componentPath) {
                Write-Status "Applying $comp..."
                Push-Location $componentPath
                
                try {
                    $result = terragrunt apply --terragrunt-non-interactive -auto-approve
                    if ($LASTEXITCODE -ne 0) {
                        Write-Error "Failed to apply $comp"
                        exit 1
                    }
                    
                    Write-Success "Successfully applied $comp"
                }
                finally {
                    Pop-Location
                }
            }
            else {
                Write-Warning "Component $comp not found, skipping..."
            }
        }
        
        Write-Success "All components applied successfully"
    }
    finally {
        Pop-Location
    }
}

# Function to destroy components
function Invoke-DestroyComponents {
    $components = Get-Components
    Write-Warning "Destroying components: $($components -join ', ')"
    
    # Confirm destruction
    $confirm = Read-Host "Are you sure you want to destroy the selected components? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Status "Destruction cancelled"
        exit 0
    }
    
    Push-Location $DevEnvDir
    
    try {
        # Destroy in reverse order
        if ($Component -eq "all") {
            $components = @("cloudfront", "route53-acm", "s3-content", "s3-website", "cognito")
        }
        
        foreach ($comp in $components) {
            $componentPath = Join-Path $DevEnvDir $comp
            if (Test-Path $componentPath) {
                Write-Status "Destroying $comp..."
                Push-Location $componentPath
                
                try {
                    $result = terragrunt destroy --terragrunt-non-interactive -auto-approve
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning "Failed to destroy $comp, continuing..."
                    }
                    else {
                        Write-Success "Successfully destroyed $comp"
                    }
                }
                finally {
                    Pop-Location
                }
            }
            else {
                Write-Warning "Component $comp not found, skipping..."
            }
        }
        
        Write-Success "Destruction completed"
    }
    finally {
        Pop-Location
    }
}

# Function to verify deployment
function Test-Deployment {
    Write-Status "Verifying deployment..."
    
    Push-Location $DevEnvDir
    
    try {
        $components = Get-Components
        
        foreach ($comp in $components) {
            $componentPath = Join-Path $DevEnvDir $comp
            if (Test-Path $componentPath) {
                Write-Status "Verifying $comp outputs..."
                Push-Location $componentPath
                
                try {
                    $result = terragrunt output --terragrunt-non-interactive
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning "No outputs for $comp"
                    }
                }
                finally {
                    Pop-Location
                }
            }
        }
        
        Write-Success "Deployment verification completed"
    }
    finally {
        Pop-Location
    }
}

# Main execution
function Main {
    # Show help if requested
    if ($Help) {
        Show-Usage
        exit 0
    }
    
    # Validate arguments
    $validComponents = @("all", "cognito", "s3-website", "s3-content", "cloudfront", "route53-acm")
    if ($Component -notin $validComponents) {
        Write-Error "Invalid component: $Component"
        Show-Usage
        exit 1
    }
    
    $validActions = @("plan", "apply", "destroy")
    if ($Action -notin $validActions) {
        Write-Error "Invalid action: $Action"
        Show-Usage
        exit 1
    }
    
    Write-Status "Starting development deployment script"
    Write-Status "Component: $Component, Action: $Action"
    
    # Check prerequisites
    Test-Prerequisites
    
    # Validate configuration
    Test-TerraformConfiguration
    
    # Run security scan
    Invoke-SecurityScan
    
    # Execute action
    switch ($Action) {
        "plan" {
            Invoke-PlanComponents
        }
        "apply" {
            Invoke-PlanComponents
            Invoke-ApplyComponents
            Test-Deployment
        }
        "destroy" {
            Invoke-DestroyComponents
        }
    }
    
    Write-Success "Development deployment script completed successfully!"
}

# Run main function
Main