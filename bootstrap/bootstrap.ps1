# Bootstrap script to initialize Terraform state infrastructure
# This script creates the S3 bucket and DynamoDB table required for remote state

$ErrorActionPreference = "Stop"

Write-Host "🚀 Bootstrapping Terraform state infrastructure..." -ForegroundColor Green

# Check if AWS CLI is configured
try {
    $null = aws sts get-caller-identity 2>$null
} catch {
    Write-Host "❌ Error: AWS CLI is not configured or credentials are invalid" -ForegroundColor Red
    Write-Host "Please run 'aws configure' to set up your AWS credentials" -ForegroundColor Yellow
    exit 1
}

# Get current directory and change to script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$AccountId = aws sts get-caller-identity --query Account --output text
$Region = aws configure get region

Write-Host "📋 Current AWS Account: $AccountId" -ForegroundColor Cyan
Write-Host "🌍 Current AWS Region: $Region" -ForegroundColor Cyan

# Initialize Terraform
Write-Host "🔧 Initializing Terraform..." -ForegroundColor Yellow
terraform init

# Plan the infrastructure
Write-Host "📝 Planning bootstrap infrastructure..." -ForegroundColor Yellow
terraform plan -out=bootstrap.tfplan

# Ask for confirmation
Write-Host ""
$Confirmation = Read-Host "🤔 Do you want to apply the bootstrap infrastructure? (y/N)"

if ($Confirmation -match "^[Yy]$") {
    Write-Host "✅ Applying bootstrap infrastructure..." -ForegroundColor Green
    terraform apply bootstrap.tfplan
    
    $BucketName = terraform output -raw state_bucket_name
    $TableName = terraform output -raw dynamodb_table_name
    
    Write-Host ""
    Write-Host "🎉 Bootstrap infrastructure created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Resources created:" -ForegroundColor Cyan
    Write-Host "   • S3 Bucket: $BucketName" -ForegroundColor White
    Write-Host "   • DynamoDB Table: $TableName" -ForegroundColor White
    Write-Host ""
    Write-Host "🔄 You can now use Terragrunt to deploy your environments!" -ForegroundColor Green
    Write-Host "   • Run 'terragrunt plan' in any environment directory" -ForegroundColor White
    Write-Host "   • Run 'terragrunt apply' to deploy resources" -ForegroundColor White
    
    # Clean up plan file
    Remove-Item -Path "bootstrap.tfplan" -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "❌ Bootstrap cancelled" -ForegroundColor Red
    Remove-Item -Path "bootstrap.tfplan" -Force -ErrorAction SilentlyContinue
    exit 1
}