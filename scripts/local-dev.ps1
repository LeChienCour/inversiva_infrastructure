# Local Development and Testing Script (PowerShell)
# This script provides utilities for local development and testing of the infrastructure

param(
    [Parameter(Position=0)]
    [ValidateSet("setup", "plan", "apply", "test", "validate", "format", "docs", "clean", "help")]
    [string]$Command,
    
    [Alias("e")]
    [string]$Environment = "dev",
    
    [Alias("m")]
    [string]$Module = "",
    
    [Alias("t")]
    [ValidateSet("unit", "integration", "smoke", "all")]
    [string]$TestType = "all",
    
    [Alias("f")]
    [switch]$Fix,
    
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
Local Development and Testing Script

USAGE:
    .\local-dev.ps1 [COMMAND] [OPTIONS]

COMMANDS:
    setup       Set up local development environment
    plan        Run Terragrunt plan for modules
    apply       Apply Terragrunt changes
    test        Run infrastructure tests
    validate    Validate Terraform configuration
    format      Format Terraform files
    docs        Generate documentation
    clean       Clean up temporary files
    help        Show this help message

OPTIONS:
    -Environment, -e ENV    Environment to work with (dev/prod) [default: dev]
    -Module, -m MODULE      Specific module to work with
    -TestType, -t TYPE      Test type (unit/integration/smoke/all) [default: all]
    -Fix, -f               Auto-fix issues where possible
    -Verbose, -v           Verbose output

EXAMPLES:
    # Set up local development environment
    .\local-dev.ps1 setup
    
    # Plan changes for dev environment
    .\local-dev.ps1 plan -e dev
    
    # Apply changes to specific module
    .\local-dev.ps1 apply -e dev -m s3-website
    
    # Run all tests
    .\local-dev.ps1 test -e dev
    
    # Run only smoke tests
    .\local-dev.ps1 test -e dev -t smoke
    
    # Validate and format code
    .\local-dev.ps1 validate -f
    .\local-dev.ps1 format

"@
}

# Check if required tools are available
function Test-Dependencies {
    $MissingTools = @()
    
    if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
        $MissingTools += "terraform"
    }
    
    if (-not (Get-Command terragrunt -ErrorAction SilentlyContinue)) {
        $MissingTools += "terragrunt"
    }
    
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        $MissingTools += "aws"
    }
    
    if ($MissingTools.Count -gt 0) {
        Write-Error "Missing required tools: $($MissingTools -join ', ')"
        Write-Info "Please install the missing tools and try again"
        return $false
    }
    
    Write-Info "All required tools are available"
    return $true
}

# Set up local development environment
function Initialize-DevEnvironment {
    param([bool]$Verbose)
    
    Write-Info "Setting up local development environment..."
    
    # Check dependencies
    if (-not (Test-Dependencies)) {
        return $false
    }
    
    # Check AWS CLI configuration
    try {
        aws sts get-caller-identity | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "AWS CLI is not configured"
            Write-Info "Run 'aws configure' to set up your credentials"
            Write-Info "You can continue with validation and formatting without AWS credentials"
        }
        else {
            Write-Success "AWS CLI is configured"
        }
    }
    catch {
        Write-Warning "AWS CLI is not configured"
        Write-Info "Run 'aws configure' to set up your credentials"
    }
    
    # Initialize Terraform modules
    Write-Info "Initializing Terraform modules..."
    
    $ModulesDir = Join-Path $ProjectRoot "modules"
    Get-ChildItem -Path $ModulesDir -Directory | ForEach-Object {
        $MainTf = Join-Path $_.FullName "main.tf"
        if (Test-Path $MainTf) {
            $ModuleName = $_.Name
            
            Write-Info "Initializing module: $ModuleName"
            
            Push-Location $_.FullName
            try {
                terraform init -backend=false 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Initialized module: $ModuleName"
                }
                else {
                    Write-Warning "Failed to initialize module: $ModuleName"
                }
            }
            finally {
                Pop-Location
            }
        }
    }
    
    # Set up pre-commit hooks if available
    if (Get-Command pre-commit -ErrorAction SilentlyContinue) {
        Write-Info "Setting up pre-commit hooks..."
        $PreCommitConfig = Join-Path $ProjectRoot ".pre-commit-config.yaml"
        if (Test-Path $PreCommitConfig) {
            Push-Location $ProjectRoot
            try {
                pre-commit install | Out-Null
                Write-Success "Pre-commit hooks installed"
            }
            finally {
                Pop-Location
            }
        }
        else {
            Write-Info "No pre-commit configuration found"
        }
    }
    
    # Create local directories
    $LogsDir = Join-Path $ProjectRoot "logs"
    $TmpDir = Join-Path $ProjectRoot "tmp"
    
    if (-not (Test-Path $LogsDir)) {
        New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
    }
    
    if (-not (Test-Path $TmpDir)) {
        New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null
    }
    
    Write-Success "Local development environment setup complete!"
    
    if ($Verbose) {
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "1. Configure AWS credentials: aws configure"
        Write-Host "2. Plan infrastructure: .\local-dev.ps1 plan -e dev"
        Write-Host "3. Apply infrastructure: .\local-dev.ps1 apply -e dev"
        Write-Host "4. Run tests: .\local-dev.ps1 test -e dev"
    }
    
    return $true
}

# Run Terragrunt plan
function Invoke-TerragruntPlan {
    param(
        [string]$Environment,
        [string]$Module,
        [bool]$Verbose
    )
    
    Write-Info "Running Terragrunt plan for '$Environment' environment..."
    
    $EnvPath = Join-Path $ProjectRoot "environments\$Environment"
    
    if (-not (Test-Path $EnvPath)) {
        Write-Error "Environment directory not found: $EnvPath"
        return $false
    }
    
    if ($Module) {
        # Plan specific module
        $ModulePath = Join-Path $EnvPath $Module
        
        if (-not (Test-Path $ModulePath)) {
            Write-Error "Module directory not found: $ModulePath"
            return $false
        }
        
        Write-Info "Planning module: $Module"
        
        Push-Location $ModulePath
        try {
            terragrunt plan
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Plan completed for module: $Module"
                return $true
            }
            else {
                Write-Error "Plan failed for module: $Module"
                return $false
            }
        }
        finally {
            Pop-Location
        }
    }
    else {
        # Plan all modules
        Write-Info "Planning all modules in environment: $Environment"
        
        Push-Location $EnvPath
        try {
            terragrunt run-all plan
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Plan completed for all modules"
                return $true
            }
            else {
                Write-Error "Plan failed for one or more modules"
                return $false
            }
        }
        finally {
            Pop-Location
        }
    }
}

# Apply Terragrunt changes
function Invoke-TerragruntApply {
    param(
        [string]$Environment,
        [string]$Module,
        [bool]$Verbose
    )
    
    Write-Info "Applying Terragrunt changes for '$Environment' environment..."
    
    $EnvPath = Join-Path $ProjectRoot "environments\$Environment"
    
    if (-not (Test-Path $EnvPath)) {
        Write-Error "Environment directory not found: $EnvPath"
        return $false
    }
    
    # Confirmation for apply
    Write-Host ""
    Write-Warning "You are about to apply changes to the '$Environment' environment"
    if ($Module) {
        Write-Warning "Module: $Module"
    }
    else {
        Write-Warning "All modules will be affected"
    }
    Write-Host ""
    
    $Confirmation = Read-Host "Are you sure you want to continue? (type 'yes' to confirm)"
    
    if ($Confirmation -ne "yes") {
        Write-Info "Apply cancelled by user"
        return $true
    }
    
    if ($Module) {
        # Apply specific module
        $ModulePath = Join-Path $EnvPath $Module
        
        if (-not (Test-Path $ModulePath)) {
            Write-Error "Module directory not found: $ModulePath"
            return $false
        }
        
        Write-Info "Applying module: $Module"
        
        Push-Location $ModulePath
        try {
            terragrunt apply
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Apply completed for module: $Module"
                return $true
            }
            else {
                Write-Error "Apply failed for module: $Module"
                return $false
            }
        }
        finally {
            Pop-Location
        }
    }
    else {
        # Apply all modules
        Write-Info "Applying all modules in environment: $Environment"
        
        Push-Location $EnvPath
        try {
            terragrunt run-all apply
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Apply completed for all modules"
                return $true
            }
            else {
                Write-Error "Apply failed for one or more modules"
                return $false
            }
        }
        finally {
            Pop-Location
        }
    }
}

# Run infrastructure tests
function Invoke-InfrastructureTests {
    param(
        [string]$Environment,
        [string]$TestType,
        [bool]$Verbose
    )
    
    Write-Info "Running infrastructure tests..."
    
    $TestDir = Join-Path $ProjectRoot "test"
    
    if (-not (Test-Path $TestDir)) {
        Write-Error "Test directory not found: $TestDir"
        return $false
    }
    
    Push-Location $TestDir
    try {
        switch ($TestType) {
            "unit" {
                Write-Info "Running unit tests..."
                make test-modules
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Unit tests passed"
                }
                else {
                    Write-Error "Unit tests failed"
                    return $false
                }
            }
            "integration" {
                Write-Info "Running integration tests..."
                $env:ENV = $Environment
                make test-integration
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Integration tests passed"
                }
                else {
                    Write-Error "Integration tests failed"
                    return $false
                }
            }
            "smoke" {
                Write-Info "Running smoke tests..."
                $env:ENV = $Environment
                make test-smoke
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Smoke tests passed"
                }
                else {
                    Write-Error "Smoke tests failed"
                    return $false
                }
            }
            default {
                Write-Info "Running all tests..."
                
                # Run tests in order
                $TestTypes = @("unit", "integration", "smoke")
                foreach ($Type in $TestTypes) {
                    Write-Info "Running $Type tests..."
                    
                    switch ($Type) {
                        "unit" {
                            make test-modules
                        }
                        "integration" {
                            $env:ENV = $Environment
                            make test-integration
                        }
                        "smoke" {
                            $env:ENV = $Environment
                            make test-smoke
                        }
                    }
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "$Type tests passed"
                    }
                    else {
                        Write-Error "$Type tests failed"
                        return $false
                    }
                }
            }
        }
        
        Write-Success "All tests completed successfully"
        return $true
    }
    finally {
        Pop-Location
    }
}

# Validate Terraform configuration
function Test-TerraformConfiguration {
    param(
        [bool]$Fix,
        [bool]$Verbose
    )
    
    Write-Info "Validating Terraform configuration..."
    
    $ValidationErrors = 0
    
    # Validate modules
    $ModulesDir = Join-Path $ProjectRoot "modules"
    Get-ChildItem -Path $ModulesDir -Directory | ForEach-Object {
        $MainTf = Join-Path $_.FullName "main.tf"
        if (Test-Path $MainTf) {
            $ModuleName = $_.Name
            
            Write-Info "Validating module: $ModuleName"
            
            Push-Location $_.FullName
            try {
                # Initialize if needed
                if (-not (Test-Path ".terraform")) {
                    terraform init -backend=false 2>$null | Out-Null
                }
                
                # Validate
                terraform validate 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Module $ModuleName is valid"
                }
                else {
                    Write-Error "Validation failed for module: $ModuleName"
                    $ValidationErrors++
                }
            }
            finally {
                Pop-Location
            }
        }
    }
    
    # Validate environments
    $EnvironmentsDir = Join-Path $ProjectRoot "environments"
    Get-ChildItem -Path $EnvironmentsDir -Directory | ForEach-Object {
        $EnvName = $_.Name
        
        Write-Info "Validating environment: $EnvName"
        
        Get-ChildItem -Path $_.FullName -Directory | ForEach-Object {
            $TerragruntFile = Join-Path $_.FullName "terragrunt.hcl"
            if (Test-Path $TerragruntFile) {
                $ModuleName = $_.Name
                
                Push-Location $_.FullName
                try {
                    terragrunt validate 2>$null | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        if ($Verbose) {
                            Write-Success "Environment $EnvName/$ModuleName is valid"
                        }
                    }
                    else {
                        Write-Error "Validation failed for environment: $EnvName/$ModuleName"
                        $ValidationErrors++
                        
                        if ($Verbose) {
                            terragrunt validate
                        }
                    }
                }
                finally {
                    Pop-Location
                }
            }
        }
    }
    
    if ($ValidationErrors -eq 0) {
        Write-Success "All configurations are valid"
        return $true
    }
    else {
        Write-Error "Found $ValidationErrors validation errors"
        return $false
    }
}

# Format Terraform files
function Format-TerraformFiles {
    param(
        [bool]$Fix,
        [bool]$Verbose
    )
    
    Write-Info "Formatting Terraform files..."
    
    # Format modules
    $ModulesDir = Join-Path $ProjectRoot "modules"
    Get-ChildItem -Path $ModulesDir -Directory | ForEach-Object {
        $MainTf = Join-Path $_.FullName "main.tf"
        if (Test-Path $MainTf) {
            $ModuleName = $_.Name
            
            Push-Location $_.FullName
            try {
                if ($Fix) {
                    terraform fmt -recursive | Out-Null
                    Write-Info "Formatted module: $ModuleName"
                }
                else {
                    terraform fmt -check -recursive 2>$null | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        if ($Verbose) {
                            Write-Success "Module $ModuleName is properly formatted"
                        }
                    }
                    else {
                        Write-Warning "Module $ModuleName needs formatting"
                    }
                }
            }
            finally {
                Pop-Location
            }
        }
    }
    
    # Format root files
    Push-Location $ProjectRoot
    try {
        if ($Fix) {
            terraform fmt -recursive | Out-Null
            Write-Info "Formatted root directory"
        }
        else {
            terraform fmt -check -recursive 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                if ($Verbose) {
                    Write-Success "Root directory is properly formatted"
                }
            }
            else {
                Write-Warning "Root directory needs formatting"
            }
        }
    }
    finally {
        Pop-Location
    }
    
    if ($Fix) {
        Write-Success "All files have been formatted"
    }
    else {
        Write-Success "Format check completed"
    }
    
    return $true
}

# Generate documentation
function New-Documentation {
    param([bool]$Verbose)
    
    Write-Info "Generating documentation..."
    
    # Generate module documentation
    $ModulesDir = Join-Path $ProjectRoot "modules"
    Get-ChildItem -Path $ModulesDir -Directory | ForEach-Object {
        $MainTf = Join-Path $_.FullName "main.tf"
        if (Test-Path $MainTf) {
            $ModuleName = $_.Name
            
            Write-Info "Generating docs for module: $ModuleName"
            
            Push-Location $_.FullName
            try {
                # Use terraform-docs if available
                if (Get-Command terraform-docs -ErrorAction SilentlyContinue) {
                    terraform-docs markdown table --output-file README.md . | Out-Null
                    Write-Success "Generated docs for module: $ModuleName"
                }
                else {
                    Write-Warning "terraform-docs not available, skipping module: $ModuleName"
                }
            }
            finally {
                Pop-Location
            }
        }
    }
    
    Write-Success "Documentation generation completed"
    return $true
}

# Clean up temporary files
function Remove-TemporaryFiles {
    param([bool]$Verbose)
    
    Write-Info "Cleaning up temporary files..."
    
    # Clean Terraform files
    Get-ChildItem -Path $ProjectRoot -Recurse -Directory -Name ".terraform" -ErrorAction SilentlyContinue | ForEach-Object {
        $Path = Join-Path $ProjectRoot $_
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Get-ChildItem -Path $ProjectRoot -Recurse -File -Name "*.tfplan" -ErrorAction SilentlyContinue | ForEach-Object {
        $Path = Join-Path $ProjectRoot $_
        Remove-Item -Path $Path -Force -ErrorAction SilentlyContinue
    }
    
    Get-ChildItem -Path $ProjectRoot -Recurse -Directory -Name ".terragrunt-cache" -ErrorAction SilentlyContinue | ForEach-Object {
        $Path = Join-Path $ProjectRoot $_
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Clean log files
    $LogsDir = Join-Path $ProjectRoot "logs"
    $TmpDir = Join-Path $ProjectRoot "tmp"
    
    if (Test-Path $LogsDir) {
        Get-ChildItem -Path $LogsDir | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    if (Test-Path $TmpDir) {
        Get-ChildItem -Path $TmpDir | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Write-Success "Temporary files cleaned up"
    return $true
}

# Main execution
function Main {
    # Show help if no command provided
    if (-not $Command) {
        Show-Help
        return
    }
    
    # Execute command
    $Success = $true
    
    switch ($Command) {
        "setup" {
            $Success = Initialize-DevEnvironment $Verbose.IsPresent
        }
        "plan" {
            $Success = Invoke-TerragruntPlan $Environment $Module $Verbose.IsPresent
        }
        "apply" {
            $Success = Invoke-TerragruntApply $Environment $Module $Verbose.IsPresent
        }
        "test" {
            $Success = Invoke-InfrastructureTests $Environment $TestType $Verbose.IsPresent
        }
        "validate" {
            $Success = Test-TerraformConfiguration $Fix.IsPresent $Verbose.IsPresent
        }
        "format" {
            $Success = Format-TerraformFiles $Fix.IsPresent $Verbose.IsPresent
        }
        "docs" {
            $Success = New-Documentation $Verbose.IsPresent
        }
        "clean" {
            $Success = Remove-TemporaryFiles $Verbose.IsPresent
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