# Root-level Terragrunt orchestration script (PowerShell)
# Usage: .\scripts\terragrunt-root.ps1 [environment] [action]
# Examples:
#   .\scripts\terragrunt-root.ps1 dev plan
#   .\scripts\terragrunt-root.ps1 prod apply

param(
    [string]$Environment = "dev",
    [string]$Action = "plan"
)

# Colors for output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Blue"

Write-Host "🚀 Root Terragrunt Orchestration" -ForegroundColor $Blue
Write-Host "================================" -ForegroundColor $Blue
Write-Host "Environment: $Environment" -ForegroundColor $Green
Write-Host "Action: $Action" -ForegroundColor $Green
Write-Host "Working from: $(Get-Location)" -ForegroundColor $Blue
Write-Host ""

# Check prerequisites
Write-Host "📋 Checking prerequisites..." -ForegroundColor $Yellow

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

# Validate environment directory exists
$EnvDir = "environments\$Environment"
if (!(Test-Path $EnvDir)) {
    Write-Host "❌ Environment directory '$EnvDir' not found" -ForegroundColor $Red
    exit 1
}

# Execute terragrunt run-all from root
Write-Host "🔧 Executing terragrunt run-all $Action for $Environment environment..." -ForegroundColor $Yellow
Write-Host ""

switch ($Action) {
    "plan" {
        terragrunt run-all plan --terragrunt-working-dir $EnvDir --terragrunt-non-interactive
    }
    "apply" {
        Write-Host "⚠️  This will apply changes to your infrastructure. Continue? (y/N)" -ForegroundColor $Yellow
        $response = Read-Host
        if ($response -match "^[yY]([eE][sS])?$") {
            terragrunt run-all apply --terragrunt-working-dir $EnvDir --terragrunt-non-interactive
        } else {
            Write-Host "❌ Apply cancelled by user" -ForegroundColor $Yellow
            exit 0
        }
    }
    "destroy" {
        Write-Host "⚠️  This will DESTROY your infrastructure. Type 'yes' to confirm:" -ForegroundColor $Red
        $response = Read-Host
        if ($response -eq "yes") {
            terragrunt run-all destroy --terragrunt-working-dir $EnvDir --terragrunt-non-interactive
        } else {
            Write-Host "❌ Destroy cancelled by user" -ForegroundColor $Yellow
            exit 0
        }
    }
    "output" {
        terragrunt run-all output --terragrunt-working-dir $EnvDir --terragrunt-non-interactive
    }
    "init" {
        terragrunt run-all init --terragrunt-working-dir $EnvDir --terragrunt-non-interactive
    }
    default {
        Write-Host "❌ Unknown action: $Action" -ForegroundColor $Red
        Write-Host "Available actions: plan, apply, destroy, output, init" -ForegroundColor $Yellow
        exit 1
    }
}

Write-Host ""
Write-Host "🎉 Root orchestration completed successfully!" -ForegroundColor $Green
Write-Host "Environment: $Environment" -ForegroundColor $Blue
Write-Host "Action: $Action" -ForegroundColor $Blue