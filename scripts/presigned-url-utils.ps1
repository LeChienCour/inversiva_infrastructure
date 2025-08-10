# Presigned URL Utility Script for S3 Content Bucket (PowerShell)
# This script provides utilities for generating and testing presigned URLs

param(
    [Parameter(Position=0)]
    [ValidateSet("generate", "test", "upload", "list", "help")]
    [string]$Command,
    
    [Alias("e")]
    [string]$Environment = "dev",
    
    [Alias("b")]
    [string]$BucketName = "",
    
    [Alias("k")]
    [string]$ObjectKey = "",
    
    [Alias("f")]
    [string]$LocalFile = "",
    
    [Alias("t")]
    [int]$Expiration = 900,  # 15 minutes
    
    [Alias("r")]
    [string]$Region = "us-east-1",
    
    [Alias("u")]
    [string]$Url = "",
    
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
Presigned URL Utility Script

USAGE:
    .\presigned-url-utils.ps1 [COMMAND] [OPTIONS]

COMMANDS:
    generate    Generate a presigned URL for an S3 object
    test        Test a presigned URL by attempting to access it
    upload      Upload a file and generate a presigned URL
    list        List objects in the content bucket
    help        Show this help message

OPTIONS:
    -Environment, -e ENV     Environment (dev/prod) [default: dev]
    -BucketName, -b BUCKET   S3 bucket name (auto-detected if not provided)
    -ObjectKey, -k KEY       S3 object key
    -LocalFile, -f FILE      Local file path
    -Expiration, -t TIME     Expiration time in seconds [default: 900]
    -Region, -r REGION       AWS region [default: us-east-1]
    -Url, -u URL            Presigned URL to test
    -Verbose, -v            Verbose output

EXAMPLES:
    # Generate presigned URL for existing object
    .\presigned-url-utils.ps1 generate -e dev -k "users/user123/document.pdf"
    
    # Upload file and generate presigned URL
    .\presigned-url-utils.ps1 upload -e dev -f ".\test-file.txt" -k "users/user123/test-file.txt"
    
    # Test a presigned URL
    .\presigned-url-utils.ps1 test -u "https://bucket.s3.amazonaws.com/object?..."
    
    # List objects in bucket
    .\presigned-url-utils.ps1 list -e prod -v

"@
}

# Get bucket name from Terragrunt outputs
function Get-BucketName {
    param([string]$Environment)
    
    $ContentPath = Join-Path $ProjectRoot "environments\$Environment\s3-content"
    
    if (Test-Path $ContentPath) {
        Push-Location $ContentPath
        try {
            $BucketName = terragrunt output -raw bucket_name 2>$null
            if ($LASTEXITCODE -eq 0 -and $BucketName) {
                return $BucketName
            }
        }
        finally {
            Pop-Location
        }
    }
    
    Write-Error "Could not retrieve bucket name for environment: $Environment"
    Write-Info "Make sure the infrastructure is deployed and Terragrunt outputs are available"
    return $null
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

# Generate presigned URL
function New-PresignedUrl {
    param(
        [string]$Environment,
        [string]$BucketName,
        [string]$ObjectKey,
        [int]$Expiration,
        [bool]$Verbose
    )
    
    if (-not $BucketName) {
        $BucketName = Get-BucketName $Environment
        if (-not $BucketName) {
            return $false
        }
    }
    
    Write-Info "Generating presigned URL..."
    Write-Info "Environment: $Environment"
    Write-Info "Bucket: $BucketName"
    Write-Info "Object Key: $ObjectKey"
    Write-Info "Expiration: $Expiration seconds"
    
    # Check if object exists
    try {
        aws s3api head-object --bucket $BucketName --key $ObjectKey 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Object does not exist: s3://$BucketName/$ObjectKey"
            Write-Info "You can upload it first using the 'upload' command"
        }
    }
    catch {
        Write-Warning "Could not check if object exists"
    }
    
    # Generate presigned URL
    try {
        $PresignedUrl = aws s3 presign "s3://$BucketName/$ObjectKey" --expires-in $Expiration
        if ($LASTEXITCODE -eq 0 -and $PresignedUrl) {
            Write-Success "Presigned URL generated successfully!"
            Write-Host ""
            Write-Host "URL: $PresignedUrl"
            Write-Host ""
            
            $ExpirationTime = (Get-Date).AddSeconds($Expiration)
            Write-Info "This URL will expire at: $($ExpirationTime.ToString('yyyy-MM-dd HH:mm:ss'))"
            
            if ($Verbose) {
                Write-Host ""
                Write-Host "Test with PowerShell:"
                Write-Host "Invoke-WebRequest -Uri `"$PresignedUrl`" -Method Head"
            }
            return $true
        }
        else {
            Write-Error "Failed to generate presigned URL"
            return $false
        }
    }
    catch {
        Write-Error "Failed to generate presigned URL: $($_.Exception.Message)"
        return $false
    }
}

# Test presigned URL
function Test-PresignedUrl {
    param(
        [string]$Url,
        [bool]$Verbose
    )
    
    Write-Info "Testing presigned URL..."
    
    if ($Verbose) {
        Write-Info "URL: $Url"
    }
    
    try {
        $Response = Invoke-WebRequest -Uri $Url -Method Head -ErrorAction Stop
        
        Write-Success "Presigned URL is valid and accessible (HTTP $($Response.StatusCode))"
        
        # Get additional info
        $ContentLength = $Response.Headers['Content-Length']
        $ContentType = $Response.Headers['Content-Type']
        
        if ($ContentLength) {
            Write-Info "Content Length: $ContentLength bytes"
        }
        if ($ContentType) {
            Write-Info "Content Type: $ContentType"
        }
        
        return $true
    }
    catch {
        $StatusCode = $_.Exception.Response.StatusCode.value__
        
        switch ($StatusCode) {
            403 {
                Write-Error "Access denied (HTTP $StatusCode) - URL may be expired or invalid"
            }
            404 {
                Write-Error "Object not found (HTTP $StatusCode)"
            }
            default {
                Write-Error "Unexpected response code: $StatusCode"
            }
        }
        return $false
    }
}

# Upload file and generate presigned URL
function Add-FileAndGenerateUrl {
    param(
        [string]$Environment,
        [string]$BucketName,
        [string]$LocalFile,
        [string]$ObjectKey,
        [int]$Expiration,
        [bool]$Verbose
    )
    
    if (-not (Test-Path $LocalFile)) {
        Write-Error "Local file does not exist: $LocalFile"
        return $false
    }
    
    if (-not $BucketName) {
        $BucketName = Get-BucketName $Environment
        if (-not $BucketName) {
            return $false
        }
    }
    
    Write-Info "Uploading file to S3..."
    Write-Info "Local file: $LocalFile"
    Write-Info "S3 location: s3://$BucketName/$ObjectKey"
    
    # Upload file
    try {
        aws s3 cp $LocalFile "s3://$BucketName/$ObjectKey"
        if ($LASTEXITCODE -eq 0) {
            Write-Success "File uploaded successfully!"
            
            # Generate presigned URL
            return New-PresignedUrl $Environment $BucketName $ObjectKey $Expiration $Verbose
        }
        else {
            Write-Error "Failed to upload file"
            return $false
        }
    }
    catch {
        Write-Error "Failed to upload file: $($_.Exception.Message)"
        return $false
    }
}

# List objects in bucket
function Get-BucketObjects {
    param(
        [string]$Environment,
        [string]$BucketName,
        [bool]$Verbose
    )
    
    if (-not $BucketName) {
        $BucketName = Get-BucketName $Environment
        if (-not $BucketName) {
            return $false
        }
    }
    
    Write-Info "Listing objects in bucket: $BucketName"
    
    try {
        if ($Verbose) {
            aws s3 ls "s3://$BucketName" --recursive --human-readable --summarize
        }
        else {
            aws s3 ls "s3://$BucketName" --recursive
        }
        return $true
    }
    catch {
        Write-Error "Failed to list objects: $($_.Exception.Message)"
        return $false
    }
}

# Main execution
function Main {
    # Show help if no command provided
    if (-not $Command) {
        Show-Help
        return
    }
    
    # Set AWS region
    $env:AWS_DEFAULT_REGION = $Region
    
    # Check AWS CLI
    if (-not (Test-AwsCli)) {
        exit 1
    }
    
    # Execute command
    switch ($Command) {
        "generate" {
            if (-not $ObjectKey) {
                Write-Error "Object key is required for generate command"
                Write-Info "Use -ObjectKey or -k to specify the S3 object key"
                exit 1
            }
            if (-not (New-PresignedUrl $Environment $BucketName $ObjectKey $Expiration $Verbose.IsPresent)) {
                exit 1
            }
        }
        "test" {
            if (-not $Url) {
                Write-Error "URL is required for test command"
                Write-Info "Use -Url or -u to specify the presigned URL to test"
                exit 1
            }
            if (-not (Test-PresignedUrl $Url $Verbose.IsPresent)) {
                exit 1
            }
        }
        "upload" {
            if (-not $LocalFile -or -not $ObjectKey) {
                Write-Error "Both local file and object key are required for upload command"
                Write-Info "Use -LocalFile or -f to specify the local file"
                Write-Info "Use -ObjectKey or -k to specify the S3 object key"
                exit 1
            }
            if (-not (Add-FileAndGenerateUrl $Environment $BucketName $LocalFile $ObjectKey $Expiration $Verbose.IsPresent)) {
                exit 1
            }
        }
        "list" {
            if (-not (Get-BucketObjects $Environment $BucketName $Verbose.IsPresent)) {
                exit 1
            }
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