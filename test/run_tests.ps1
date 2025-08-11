# Terraform Next.js Infrastructure Test Runner (PowerShell)
# This script provides a convenient way to run different test suites on Windows

param(
    [Parameter(Position=0)]
    [string]$Command = "help",
    
    [Parameter(Position=1)]
    [string]$TestName = "",
    
    [string]$AwsRegion = $env:AWS_REGION ?? "us-east-1",
    [string]$TestEnvironment = $env:TEST_ENVIRONMENT ?? "test",
    [string]$CleanupResources = $env:CLEANUP_RESOURCES ?? "true",
    [string]$TestTimeout = $env:TEST_TIMEOUT ?? "30m",
    [int]$Parallel = [int]($env:PARALLEL ?? "2")
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to print colored output
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

# Function to check prerequisites
function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    # Check Go installation
    try {
        $goVersion = go version
        Write-Info "Go is installed: $goVersion"
    }
    catch {
        Write-Error "Go is not installed. Please install Go 1.21 or later."
        exit 1
    }
    
    # Check Terraform
    try {
        $terraformVersion = terraform version
        Write-Info "Terraform is installed: $($terraformVersion.Split("`n")[0])"
    }
    catch {
        Write-Error "Terraform is not installed."
        exit 1
    }
    
    # Check Terragrunt
    try {
        $terragruntVersion = terragrunt --version
        Write-Info "Terragrunt is installed: $terragruntVersion"
    }
    catch {
        Write-Error "Terragrunt is not installed."
        exit 1
    }
    
    # Check AWS CLI
    try {
        $awsVersion = aws --version
        Write-Info "AWS CLI is installed: $awsVersion"
    }
    catch {
        Write-Error "AWS CLI is not installed."
        exit 1
    }
    
    # Check AWS credentials
    try {
        $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
        Write-Info "AWS credentials are valid for: $($identity.Arn)"
    }
    catch {
        Write-Error "AWS credentials are not configured or invalid."
        Write-Info "Please run 'aws configure' to set up your credentials."
        exit 1
    }
    
    Write-Success "All prerequisites are met."
}

# Function to install Go dependencies
function Install-Dependencies {
    Write-Info "Installing Go dependencies..."
    go mod download
    go mod tidy
    Write-Success "Dependencies installed."
}

# Function to set environment variables
function Set-TestEnvironment {
    $env:AWS_REGION = $AwsRegion
    $env:TEST_ENVIRONMENT = $TestEnvironment
    $env:CLEANUP_RESOURCES = $CleanupResources
}

# Function to run specific test suite
function Invoke-TestSuite {
    param(
        [string]$Suite,
        [string]$Description
    )
    
    Write-Info "Running $Description..."
    
    Set-TestEnvironment
    
    try {
        go test -v -timeout $TestTimeout -parallel $Parallel "./$Suite/..."
        Write-Success "$Description completed successfully."
        return $true
    }
    catch {
        Write-Error "$Description failed."
        return $false
    }
}

# Function to run all tests
function Invoke-AllTests {
    Write-Info "Running all test suites..."
    
    $failedSuites = @()
    
    # Run each test suite
    if (-not (Invoke-TestSuite "modules" "Module unit tests")) {
        $failedSuites += "modules"
    }
    
    if (-not (Invoke-TestSuite "integration" "Integration tests")) {
        $failedSuites += "integration"
    }
    
    if (-not (Invoke-TestSuite "smoke" "Smoke tests")) {
        $failedSuites += "smoke"
    }
    
    if (-not (Invoke-TestSuite "security" "Security tests")) {
        $failedSuites += "security"
    }
    
    if (-not (Invoke-TestSuite "cost" "Cost optimization tests")) {
        $failedSuites += "cost"
    }
    
    # Report results
    if ($failedSuites.Count -eq 0) {
        Write-Success "All test suites passed!"
        return $true
    }
    else {
        Write-Error "The following test suites failed: $($failedSuites -join ', ')"
        return $false
    }
}

# Function to run quick tests
function Invoke-QuickTests {
    Write-Info "Running quick tests (short mode)..."
    
    Set-TestEnvironment
    
    try {
        go test -v -short -timeout "10m" -parallel $Parallel "./modules/..."
        Write-Success "Quick tests completed successfully."
        return $true
    }
    catch {
        Write-Error "Quick tests failed."
        return $false
    }
}

# Function to run specific test
function Invoke-SpecificTest {
    param([string]$TestName)
    
    if ([string]::IsNullOrEmpty($TestName)) {
        Write-Error "Test name is required for specific test execution."
        Write-Info "Usage: .\run_tests.ps1 specific -TestName <TestName>"
        exit 1
    }
    
    Write-Info "Running specific test: $TestName"
    
    Set-TestEnvironment
    
    try {
        go test -v -timeout $TestTimeout -run $TestName "./..."
        Write-Success "Test $TestName completed successfully."
        return $true
    }
    catch {
        Write-Error "Test $TestName failed."
        return $false
    }
}

# Function to clean up test artifacts
function Clear-TestArtifacts {
    Write-Info "Cleaning up test artifacts..."
    
    go clean -testcache
    
    # Remove Terraform state files
    Get-ChildItem -Path . -Recurse -Name "*.tfstate*" | Remove-Item -Force -ErrorAction SilentlyContinue
    
    # Remove Terraform directories
    Get-ChildItem -Path . -Recurse -Directory -Name ".terraform" | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    
    # Remove Terraform lock files
    Get-ChildItem -Path . -Recurse -Name ".terraform.lock.hcl" | Remove-Item -Force -ErrorAction SilentlyContinue
    
    Write-Success "Cleanup completed."
}

# Function to show usage
function Show-Usage {
    Write-Host "Terraform Next.js Infrastructure Test Runner (PowerShell)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\run_tests.ps1 [command] [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Yellow
    Write-Host "  all                 Run all test suites"
    Write-Host "  modules             Run module unit tests"
    Write-Host "  integration         Run integration tests"
    Write-Host "  smoke               Run smoke tests"
    Write-Host "  security            Run security tests"
    Write-Host "  cost                Run cost optimization tests"
    Write-Host "  quick               Run quick tests (short mode)"
    Write-Host "  specific            Run specific test by name"
    Write-Host "  cleanup             Clean up test artifacts"
    Write-Host "  help                Show this help message"
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  -AwsRegion          AWS region for testing (default: us-east-1)"
    Write-Host "  -TestEnvironment    Test environment name (default: test)"
    Write-Host "  -CleanupResources   Whether to cleanup resources (default: true)"
    Write-Host "  -TestTimeout        Test timeout duration (default: 30m)"
    Write-Host "  -Parallel           Number of parallel tests (default: 2)"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\run_tests.ps1 all"
    Write-Host "  .\run_tests.ps1 modules"
    Write-Host "  .\run_tests.ps1 specific -TestName TestS3WebsiteModule"
    Write-Host "  .\run_tests.ps1 quick -AwsRegion us-west-2"
    Write-Host "  .\run_tests.ps1 modules -CleanupResources false"
}

# Function to show environment info
function Show-Environment {
    Write-Info "Test Environment Configuration:"
    Write-Host "  AWS Region: $AwsRegion" -ForegroundColor White
    Write-Host "  Test Environment: $TestEnvironment" -ForegroundColor White
    Write-Host "  Cleanup Resources: $CleanupResources" -ForegroundColor White
    Write-Host "  Test Timeout: $TestTimeout" -ForegroundColor White
    Write-Host "  Parallel Tests: $Parallel" -ForegroundColor White
    Write-Host ""
    
    Write-Info "AWS Identity:"
    try {
        $identity = aws sts get-caller-identity --output table
        Write-Host $identity -ForegroundColor White
    }
    catch {
        Write-Warning "Unable to get AWS identity"
    }
    Write-Host ""
}

# Main script logic
try {
    switch ($Command.ToLower()) {
        "all" {
            Test-Prerequisites
            Install-Dependencies
            Show-Environment
            $result = Invoke-AllTests
            if (-not $result) { exit 1 }
        }
        "modules" {
            Test-Prerequisites
            Install-Dependencies
            Show-Environment
            $result = Invoke-TestSuite "modules" "Module unit tests"
            if (-not $result) { exit 1 }
        }
        "integration" {
            Test-Prerequisites
            Install-Dependencies
            Show-Environment
            $result = Invoke-TestSuite "integration" "Integration tests"
            if (-not $result) { exit 1 }
        }
        "smoke" {
            Test-Prerequisites
            Install-Dependencies
            Show-Environment
            $result = Invoke-TestSuite "smoke" "Smoke tests"
            if (-not $result) { exit 1 }
        }
        "security" {
            Test-Prerequisites
            Install-Dependencies
            Show-Environment
            $result = Invoke-TestSuite "security" "Security tests"
            if (-not $result) { exit 1 }
        }
        "cost" {
            Test-Prerequisites
            Install-Dependencies
            Show-Environment
            $result = Invoke-TestSuite "cost" "Cost optimization tests"
            if (-not $result) { exit 1 }
        }
        "quick" {
            Test-Prerequisites
            Install-Dependencies
            Show-Environment
            $result = Invoke-QuickTests
            if (-not $result) { exit 1 }
        }
        "specific" {
            Test-Prerequisites
            Install-Dependencies
            Show-Environment
            $result = Invoke-SpecificTest $TestName
            if (-not $result) { exit 1 }
        }
        "cleanup" {
            Clear-TestArtifacts
        }
        "help" {
            Show-Usage
        }
        default {
            Write-Error "Unknown command: $Command"
            Show-Usage
            exit 1
        }
    }
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}