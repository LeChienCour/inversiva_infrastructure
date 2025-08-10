#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Runs the final integration test suite for the Terraform Next.js Infrastructure project.

.DESCRIPTION
    This script executes comprehensive end-to-end integration tests that validate:
    - Complete infrastructure deployment
    - Cross-environment isolation and resource separation
    - GitHub Actions deployment workflows validation
    - Security penetration testing on deployed infrastructure

.PARAMETER TestSuite
    Specific test suite to run. Options: all, e2e, github-actions, security, cross-env, readiness

.PARAMETER AWSRegion
    AWS region for testing (default: us-east-1)

.PARAMETER TestEnvironment
    Test environment identifier (default: ci)

.PARAMETER CleanupResources
    Whether to cleanup resources after tests (default: true)

.PARAMETER Timeout
    Test timeout duration (default: 60m)

.PARAMETER Parallel
    Number of parallel test executions (default: 1)

.PARAMETER GenerateReport
    Generate detailed test report (default: true)

.EXAMPLE
    .\run_final_integration_tests.ps1 -TestSuite all
    
.EXAMPLE
    .\run_final_integration_tests.ps1 -TestSuite security -CleanupResources false
    
.EXAMPLE
    .\run_final_integration_tests.ps1 -TestSuite e2e -AWSRegion us-west-2 -Timeout 45m
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("all", "e2e", "github-actions", "security", "cross-env", "readiness", "final-suite")]
    [string]$TestSuite = "all",
    
    [Parameter(Mandatory=$false)]
    [string]$AWSRegion = "us-east-1",
    
    [Parameter(Mandatory=$false)]
    [string]$TestEnvironment = "ci",
    
    [Parameter(Mandatory=$false)]
    [bool]$CleanupResources = $true,
    
    [Parameter(Mandatory=$false)]
    [string]$Timeout = "60m",
    
    [Parameter(Mandatory=$false)]
    [int]$Parallel = 1,
    
    [Parameter(Mandatory=$false)]
    [bool]$GenerateReport = $true
)

# Colors for output
$Red = "`e[31m"
$Green = "`e[32m"
$Yellow = "`e[33m"
$Blue = "`e[34m"
$Magenta = "`e[35m"
$Cyan = "`e[36m"
$White = "`e[37m"
$Reset = "`e[0m"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = $White
    )
    Write-Host "${Color}${Message}${Reset}"
}

# Function to check prerequisites
function Test-Prerequisites {
    Write-ColorOutput "Checking prerequisites..." $Blue
    
    # Check Go installation
    try {
        $goVersion = go version
        Write-ColorOutput "✓ Go: $goVersion" $Green
    } catch {
        Write-ColorOutput "✗ Go is not installed or not in PATH" $Red
        exit 1
    }
    
    # Check AWS CLI
    try {
        $awsVersion = aws --version
        Write-ColorOutput "✓ AWS CLI: $awsVersion" $Green
    } catch {
        Write-ColorOutput "✗ AWS CLI is not installed or not in PATH" $Red
        exit 1
    }
    
    # Check Terraform
    try {
        $terraformVersion = terraform version
        Write-ColorOutput "✓ Terraform: $terraformVersion" $Green
    } catch {
        Write-ColorOutput "✗ Terraform is not installed or not in PATH" $Red
        exit 1
    }
    
    # Check Terragrunt
    try {
        $terragruntVersion = terragrunt --version
        Write-ColorOutput "✓ Terragrunt: $terragruntVersion" $Green
    } catch {
        Write-ColorOutput "✗ Terragrunt is not installed or not in PATH" $Red
        exit 1
    }
    
    # Check AWS credentials
    try {
        $awsIdentity = aws sts get-caller-identity --output text
        Write-ColorOutput "✓ AWS credentials configured" $Green
    } catch {
        Write-ColorOutput "✗ AWS credentials are not configured" $Red
        exit 1
    }
}

# Function to setup test environment
function Initialize-TestEnvironment {
    Write-ColorOutput "Setting up test environment..." $Blue
    
    # Set environment variables
    $env:AWS_REGION = $AWSRegion
    $env:TEST_ENVIRONMENT = $TestEnvironment
    $env:CLEANUP_RESOURCES = $CleanupResources.ToString().ToLower()
    $env:GO_TEST_TIMEOUT = $Timeout
    
    # Create test results directory
    $testResultsDir = "test-results"
    if (!(Test-Path $testResultsDir)) {
        New-Item -ItemType Directory -Path $testResultsDir | Out-Null
    }
    
    # Install Go dependencies
    Write-ColorOutput "Installing Go dependencies..." $Blue
    go mod download
    go mod tidy
    
    Write-ColorOutput "Test environment initialized" $Green
    Write-ColorOutput "  AWS Region: $AWSRegion" $Cyan
    Write-ColorOutput "  Test Environment: $TestEnvironment" $Cyan
    Write-ColorOutput "  Cleanup Resources: $CleanupResources" $Cyan
    Write-ColorOutput "  Timeout: $Timeout" $Cyan
    Write-ColorOutput "  Parallel: $Parallel" $Cyan
}

# Function to run specific test suite
function Invoke-TestSuite {
    param(
        [string]$Suite,
        [string]$TestPattern,
        [string]$Description
    )
    
    Write-ColorOutput "Running $Description..." $Blue
    
    $testArgs = @(
        "test"
        "-v"
        "-timeout", $Timeout
        "-parallel", $Parallel
    )
    
    if ($TestPattern) {
        $testArgs += @("-run", $TestPattern)
    }
    
    $testArgs += "./integration/..."
    
    $startTime = Get-Date
    
    try {
        & go @testArgs
        $exitCode = $LASTEXITCODE
        
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        if ($exitCode -eq 0) {
            Write-ColorOutput "✓ $Description completed successfully (Duration: $($duration.ToString('hh\:mm\:ss')))" $Green
            return $true
        } else {
            Write-ColorOutput "✗ $Description failed (Duration: $($duration.ToString('hh\:mm\:ss')))" $Red
            return $false
        }
    } catch {
        Write-ColorOutput "✗ $Description failed with exception: $_" $Red
        return $false
    }
}

# Function to generate test report
function New-TestReport {
    param(
        [hashtable]$Results
    )
    
    if (!$GenerateReport) {
        return
    }
    
    Write-ColorOutput "Generating test report..." $Blue
    
    $reportFile = "test-results/final-integration-test-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
    
    $report = @"
# Final Integration Test Report

**Generated**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Test Suite**: $TestSuite
**AWS Region**: $AWSRegion
**Test Environment**: $TestEnvironment
**Cleanup Resources**: $CleanupResources

## Test Results Summary

| Test Suite | Status | Duration |
|------------|--------|----------|
"@
    
    $totalTests = 0
    $passedTests = 0
    $failedTests = 0
    
    foreach ($test in $Results.Keys) {
        $result = $Results[$test]
        $status = if ($result.Success) { "✅ PASS" } else { "❌ FAIL" }
        $duration = $result.Duration.ToString('hh\:mm\:ss')
        
        $report += "`n| $test | $status | $duration |"
        
        $totalTests++
        if ($result.Success) {
            $passedTests++
        } else {
            $failedTests++
        }
    }
    
    $successRate = if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 2) } else { 0 }
    
    $report += @"

## Summary Statistics

- **Total Tests**: $totalTests
- **Passed**: $passedTests
- **Failed**: $failedTests
- **Success Rate**: $successRate%

## Environment Details

- **AWS Region**: $AWSRegion
- **Test Environment**: $TestEnvironment
- **Cleanup Resources**: $CleanupResources
- **Test Timeout**: $Timeout
- **Parallel Execution**: $Parallel

"@
    
    if ($failedTests -gt 0) {
        $report += @"
## ⚠️ Failed Tests

The following tests failed and require attention:

"@
        foreach ($test in $Results.Keys) {
            $result = $Results[$test]
            if (!$result.Success) {
                $report += "- **$test**: Failed after $($result.Duration.ToString('hh\:mm\:ss'))`n"
            }
        }
        
        $report += @"

### Troubleshooting Steps

1. Check the detailed test logs above
2. Verify AWS permissions and resource availability
3. Ensure all prerequisites are installed and configured
4. Check for resource conflicts or naming collisions
5. Review security group and network configurations
6. Validate Terraform and Terragrunt configurations

"@
    } else {
        $report += @"
## ✅ All Tests Passed

Congratulations! All integration tests passed successfully. The infrastructure is ready for deployment.

"@
    }
    
    # Write report to file
    $report | Out-File -FilePath $reportFile -Encoding UTF8
    Write-ColorOutput "Test report generated: $reportFile" $Green
    
    # Also output to console
    Write-ColorOutput "`n$('='*80)" $Magenta
    Write-ColorOutput "FINAL INTEGRATION TEST RESULTS" $Magenta
    Write-ColorOutput "$('='*80)" $Magenta
    Write-ColorOutput "Total Tests: $totalTests" $White
    Write-ColorOutput "Passed: $passedTests" $Green
    Write-ColorOutput "Failed: $failedTests" $Red
    Write-ColorOutput "Success Rate: $successRate%" $Cyan
    Write-ColorOutput "$('='*80)" $Magenta
}

# Main execution
function Main {
    $startTime = Get-Date
    
    Write-ColorOutput "$('='*80)" $Magenta
    Write-ColorOutput "TERRAFORM NEXT.JS INFRASTRUCTURE - FINAL INTEGRATION TESTS" $Magenta
    Write-ColorOutput "$('='*80)" $Magenta
    
    # Check prerequisites
    Test-Prerequisites
    
    # Initialize test environment
    Initialize-TestEnvironment
    
    # Results tracking
    $testResults = @{}
    
    # Run tests based on selected suite
    switch ($TestSuite) {
        "all" {
            Write-ColorOutput "Running all integration test suites..." $Yellow
            
            $testResults["Infrastructure Readiness"] = @{
                Success = (Invoke-TestSuite "readiness" "TestInfrastructureReadiness" "Infrastructure Readiness Tests")
                Duration = (Get-Date) - $startTime
            }
            
            $testResults["GitHub Actions Workflows"] = @{
                Success = (Invoke-TestSuite "github-actions" "TestGitHubActionsWorkflows|TestWorkflowSyntax|TestWorkflowSecrets" "GitHub Actions Workflow Tests")
                Duration = (Get-Date) - $startTime
            }
            
            $testResults["Cross-Environment Isolation"] = @{
                Success = (Invoke-TestSuite "cross-env" "TestCrossEnvironmentIsolation|TestResourceSeparation" "Cross-Environment Isolation Tests")
                Duration = (Get-Date) - $startTime
            }
            
            $testResults["End-to-End Deployment"] = @{
                Success = (Invoke-TestSuite "e2e" "TestCompleteInfrastructureDeployment" "End-to-End Infrastructure Deployment Tests")
                Duration = (Get-Date) - $startTime
            }
            
            $testResults["Security Penetration"] = @{
                Success = (Invoke-TestSuite "security" "TestSecurityPenetrationTesting" "Security Penetration Tests")
                Duration = (Get-Date) - $startTime
            }
        }
        
        "final-suite" {
            $testResults["Final Integration Suite"] = @{
                Success = (Invoke-TestSuite "final-suite" "TestFinalIntegrationSuite" "Complete Final Integration Test Suite")
                Duration = (Get-Date) - $startTime
            }
        }
        
        "e2e" {
            $testResults["End-to-End Deployment"] = @{
                Success = (Invoke-TestSuite "e2e" "TestCompleteInfrastructureDeployment" "End-to-End Infrastructure Deployment Tests")
                Duration = (Get-Date) - $startTime
            }
        }
        
        "github-actions" {
            $testResults["GitHub Actions Workflows"] = @{
                Success = (Invoke-TestSuite "github-actions" "TestGitHubActionsWorkflows|TestWorkflowSyntax|TestWorkflowSecrets" "GitHub Actions Workflow Tests")
                Duration = (Get-Date) - $startTime
            }
        }
        
        "security" {
            $testResults["Security Penetration"] = @{
                Success = (Invoke-TestSuite "security" "TestSecurityPenetrationTesting" "Security Penetration Tests")
                Duration = (Get-Date) - $startTime
            }
        }
        
        "cross-env" {
            $testResults["Cross-Environment Isolation"] = @{
                Success = (Invoke-TestSuite "cross-env" "TestCrossEnvironmentIsolation|TestResourceSeparation" "Cross-Environment Isolation Tests")
                Duration = (Get-Date) - $startTime
            }
        }
        
        "readiness" {
            $testResults["Infrastructure Readiness"] = @{
                Success = (Invoke-TestSuite "readiness" "TestInfrastructureReadiness|TestComplianceValidation" "Infrastructure Readiness Tests")
                Duration = (Get-Date) - $startTime
            }
        }
    }
    
    $endTime = Get-Date
    $totalDuration = $endTime - $startTime
    
    # Generate report
    New-TestReport -Results $testResults
    
    Write-ColorOutput "`nTotal execution time: $($totalDuration.ToString('hh\:mm\:ss'))" $Cyan
    
    # Determine exit code
    $failedCount = ($testResults.Values | Where-Object { !$_.Success }).Count
    if ($failedCount -gt 0) {
        Write-ColorOutput "`n❌ $failedCount test suite(s) failed" $Red
        exit 1
    } else {
        Write-ColorOutput "`n✅ All test suites passed successfully!" $Green
        exit 0
    }
}

# Execute main function
Main