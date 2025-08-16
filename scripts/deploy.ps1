# Simple deployment script for local development (PowerShell)
# Usage: .\scripts\deploy.ps1 [environment] [component] [action]

param(
    [string]$Environment = "dev",
    [string]$Component = "all", 
    [string]$Action = "plan"
)

# Function to handle lock file synchronization
function Sync-LockFile {
    param([string]$ComponentDir)
    
    $RootLockFile = "..\..\..\.terraform.lock.hcl"
    $ComponentLockFile = ".terraform.lock.hcl"
    
    # If root lock file exists and component doesn't have one, copy it
    if ((Test-Path $RootLockFile) -and !(Test-Path $ComponentLockFile)) {
        Write-Host "📋 Copying root lock file to component..." -ForegroundColor $Yellow
        Copy-Item $RootLockFile $ComponentLockFile
    }
    
    # If component has a lock file but root doesn't, copy it up
    if ((Test-Path $ComponentLockFile) -and !(Test-Path $RootLockFile)) {
        Write-Host "📋 Copying component lock file to root..." -ForegroundColor $Yellow
        Copy-Item $ComponentLockFile $RootLockFile
    }
}

# Colors for output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Blue"

Write-Host "🚀 Terraform Deployment Script" -ForegroundColor $Blue
Write-Host "================================" -ForegroundColor $Blue
Write-Host "Environment: $Environment" -ForegroundColor $Green
Write-Host "Component: $Component" -ForegroundColor $Green
Write-Host "Action: $Action" -ForegroundColor $Green
Write-Host ""

# Check prerequisites
Write-Host "📋 Checking prerequisites..." -ForegroundColor $Yellow

if (!(Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Terraform not found. Please install Terraform." -ForegroundColor $Red
    exit 1
}

if (!(Get-Command terragrunt -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Terragrunt not found. Please install Terragrunt." -ForegroundColor $Red
    exit 1
}

try {
    aws sts get-caller-identity | Out-Null
} catch {
    Write-Host "❌ AWS credentials not configured. Please run 'aws configure'." -ForegroundColor $Red
    exit 1
}

Write-Host "✅ Prerequisites check passed" -ForegroundColor $Green
Write-Host ""

# Navigate to environment directory
$EnvDir = "environments\$Environment"
if (!(Test-Path $EnvDir)) {
    Write-Host "❌ Environment directory '$EnvDir' not found" -ForegroundColor $Red
    exit 1
}

Set-Location $EnvDir

# Determine components to deploy
if ($Component -eq "all") {
    $Components = @("cognito", "s3-website", "s3-content", "route53-acm", "cloudfront", "monitoring")
} else {
    $Components = @($Component)
}

Write-Host "🔧 Components to process: $($Components -join ', ')" -ForegroundColor $Yellow
Write-Host ""

# Process each component
foreach ($comp in $Components) {
    if (!(Test-Path $comp)) {
        Write-Host "⚠️ Component '$comp' not found, skipping..." -ForegroundColor $Yellow
        continue
    }
    
    Write-Host "📦 Processing component: $comp" -ForegroundColor $Blue
    Set-Location $comp
    
    # Sync lock file before initialization
    Sync-LockFile $comp
    
    # Initialize with proper lock file handling
    Write-Host "🔄 Initializing..." -ForegroundColor $Yellow
    
    # Remove local .terraform directory to ensure clean state
    if (Test-Path ".terraform") {
        Write-Host "🧹 Cleaning local .terraform directory..." -ForegroundColor $Yellow
        Remove-Item -Recurse -Force ".terraform"
    }
    
    # Initialize with upgrade to ensure provider versions are consistent
    terragrunt init --terragrunt-non-interactive -upgrade
    
    # Validate configuration
    Write-Host "🔍 Validating configuration..." -ForegroundColor $Yellow
    terragrunt validate --terragrunt-non-interactive
    
    # Perform action
    switch ($Action) {
        "plan" {
            Write-Host "📋 Planning..." -ForegroundColor $Yellow
            terragrunt plan --terragrunt-non-interactive
        }
        "apply" {
            Write-Host "🚀 Applying..." -ForegroundColor $Yellow
            terragrunt apply --terragrunt-non-interactive -auto-approve
        }
        "destroy" {
            Write-Host "🗑️ Destroying..." -ForegroundColor $Yellow
            terragrunt destroy --terragrunt-non-interactive -auto-approve
        }
        "output" {
            Write-Host "📤 Getting outputs..." -ForegroundColor $Yellow
            terragrunt output --terragrunt-non-interactive
        }
        "refresh" {
            Write-Host "🔄 Refreshing state..." -ForegroundColor $Yellow
            terragrunt refresh --terragrunt-non-interactive
        }
        "init-only" {
            Write-Host "🔧 Initialize only (no other actions)..." -ForegroundColor $Yellow
            # Already initialized above, just validate
        }
        default {
            Write-Host "❌ Unknown action: $Action" -ForegroundColor $Red
            Write-Host "Available actions: plan, apply, destroy, output, refresh, init-only" -ForegroundColor $Yellow
            exit 1
        }
    }
    
    Write-Host "✅ Component '$comp' completed" -ForegroundColor $Green
    Set-Location ..
    Write-Host ""
}

Write-Host "🎉 Deployment completed successfully!" -ForegroundColor $Green
Write-Host "Environment: $Environment" -ForegroundColor $Blue
Write-Host "Action: $Action" -ForegroundColor $Blue
Write-Host "Components: $($Components -join ', ')" -ForegroundColor $Blue