# PowerShell deployment script for Next.js build artifacts to S3
# Uploads the Next.js build output to the S3 website bucket

param(
    [string]$AwsRegion = $env:AWS_REGION ?? "us-east-1",
    [string]$S3WebsiteBucket = $env:S3_WEBSITE_BUCKET,
    [string]$CloudFrontDistributionId = $env:CLOUDFRONT_DISTRIBUTION_ID,
    [string]$BuildDir = $env:BUILD_DIR ?? ".next/out",
    [string]$Environment = $env:ENVIRONMENT ?? "dev",
    [switch]$DeleteOldFiles = [bool]($env:DELETE_OLD_FILES -eq "true"),
    [switch]$CreateInvalidation = [bool]($env:CREATE_INVALIDATION -ne "false"),
    [switch]$DryRun = [bool]($env:DRY_RUN -eq "true"),
    [switch]$Help
)

# Cache control settings
$CacheControlSettings = @{
    Html = "public, max-age=0, s-maxage=86400, must-revalidate"
    Assets = "public, max-age=31536000, immutable"
    Api = "public, max-age=0, s-maxage=60"
    Default = "public, max-age=86400"
}

# Counters
$UploadedCount = 0
$ErrorCount = 0
$Errors = @()

# Function to write colored output
function Write-Status {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to show usage information
function Show-Usage {
    Write-Host @"
Usage: .\deploy-to-s3.ps1 [parameters]

Parameters:
  -AwsRegion                    AWS region (default: us-east-1)
  -S3WebsiteBucket             S3 bucket name for website hosting (required)
  -CloudFrontDistributionId    CloudFront distribution ID (optional)
  -BuildDir                    Build directory path (default: .next/out)
  -Environment                 Deployment environment (default: dev)
  -DeleteOldFiles              Delete old files not in current build
  -CreateInvalidation          Create CloudFront invalidation (default: true)
  -DryRun                      Show what would be done without making changes
  -Help                        Show this help message

Environment Variables (alternative to parameters):
  AWS_REGION, S3_WEBSITE_BUCKET, CLOUDFRONT_DISTRIBUTION_ID,
  BUILD_DIR, ENVIRONMENT, DELETE_OLD_FILES, CREATE_INVALIDATION, DRY_RUN

Examples:
  # Basic deployment
  .\deploy-to-s3.ps1 -S3WebsiteBucket "my-website-bucket"

  # Production deployment with CloudFront
  .\deploy-to-s3.ps1 -S3WebsiteBucket "my-website-bucket" `
                     -CloudFrontDistributionId "E1234567890123" `
                     -Environment "prod" `
                     -DeleteOldFiles `
                     -CreateInvalidation

  # Dry run to see what would be deployed
  .\deploy-to-s3.ps1 -S3WebsiteBucket "my-website-bucket" -DryRun
"@
}

# Function to validate configuration
function Test-Configuration {
    Write-Status "🔄 Validating configuration..." -Color "Blue"
    
    if (-not $S3WebsiteBucket) {
        Write-Status "❌ S3WebsiteBucket parameter is required" -Color "Red"
        exit 1
    }
    
    if (-not (Test-Path $BuildDir)) {
        Write-Status "❌ Build directory not found: $BuildDir" -Color "Red"
        exit 1
    }
    
    # Check if AWS CLI is installed
    try {
        $null = Get-Command aws -ErrorAction Stop
    }
    catch {
        Write-Status "❌ AWS CLI is not installed or not in PATH" -Color "Red"
        exit 1
    }
    
    # Check AWS credentials
    try {
        $null = aws sts get-caller-identity 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "AWS credentials check failed"
        }
    }
    catch {
        Write-Status "❌ AWS credentials not configured or invalid" -Color "Red"
        exit 1
    }
    
    Write-Status "✅ Configuration validated" -Color "Green"
}

# Function to get appropriate cache control header
function Get-CacheControl {
    param([string]$FilePath)
    
    if ($FilePath -match '\.html$') {
        return $CacheControlSettings.Html
    }
    elseif ($FilePath -match '/_next/static/') {
        return $CacheControlSettings.Assets
    }
    elseif ($FilePath -match '^api/') {
        return $CacheControlSettings.Api
    }
    else {
        return $CacheControlSettings.Default
    }
}

# Function to get content type
function Get-ContentType {
    param([string]$FilePath)
    
    $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
    
    switch ($extension) {
        ".html" { return "text/html; charset=utf-8" }
        ".js" { return "application/javascript; charset=utf-8" }
        ".css" { return "text/css; charset=utf-8" }
        ".json" { return "application/json; charset=utf-8" }
        ".png" { return "image/png" }
        ".jpg" { return "image/jpeg" }
        ".jpeg" { return "image/jpeg" }
        ".gif" { return "image/gif" }
        ".svg" { return "image/svg+xml" }
        ".ico" { return "image/x-icon" }
        ".pdf" { return "application/pdf" }
        ".txt" { return "text/plain; charset=utf-8" }
        ".xml" { return "application/xml; charset=utf-8" }
        ".woff" { return "font/woff" }
        ".woff2" { return "font/woff2" }
        ".ttf" { return "font/ttf" }
        ".eot" { return "application/vnd.ms-fontobject" }
        default { return "application/octet-stream" }
    }
}

# Function to format file size
function Format-FileSize {
    param([long]$Bytes)
    
    if ($Bytes -eq 0) { return "0 Bytes" }
    
    $sizes = @("Bytes", "KB", "MB", "GB", "TB")
    $i = [math]::Floor([math]::Log($Bytes) / [math]::Log(1024))
    
    return "{0:N2} {1}" -f ($Bytes / [math]::Pow(1024, $i)), $sizes[$i]
}

# Function to upload a single file
function Invoke-FileUpload {
    param(
        [string]$LocalPath,
        [string]$S3Key
    )
    
    $cacheControl = Get-CacheControl -FilePath $S3Key
    $contentType = Get-ContentType -FilePath $S3Key
    $fileSize = (Get-Item $LocalPath).Length
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    if ($DryRun) {
        Write-Status "🔍 [DRY RUN] Would upload: $S3Key" -Color "Yellow"
        $script:UploadedCount++
        return $true
    }
    
    try {
        # Upload file with metadata
        $awsArgs = @(
            "s3", "cp", $LocalPath, "s3://$S3WebsiteBucket/$S3Key",
            "--region", $AwsRegion,
            "--cache-control", $cacheControl,
            "--content-type", $contentType,
            "--metadata", "deployment-environment=$Environment,deployment-timestamp=$timestamp",
            "--quiet"
        )
        
        $result = & aws @awsArgs 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Status "✅ Uploaded: $S3Key ($(Format-FileSize $fileSize))" -Color "Green"
            $script:UploadedCount++
            return $true
        }
        else {
            throw "AWS CLI returned exit code $LASTEXITCODE"
        }
    }
    catch {
        Write-Status "❌ Failed to upload: $S3Key - $($_.Exception.Message)" -Color "Red"
        $script:ErrorCount++
        $script:Errors += @{ File = $S3Key; Error = $_.Exception.Message }
        return $false
    }
}

# Function to upload all files
function Invoke-FilesUpload {
    Write-Status "🔄 Scanning build directory..." -Color "Blue"
    
    $files = Get-ChildItem -Path $BuildDir -Recurse -File
    $fileCount = $files.Count
    
    Write-Status "📄 Found $fileCount files to upload" -Color "Blue"
    Write-Status "🔄 Uploading files..." -Color "Blue"
    
    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($BuildDir.Length + 1)
        # Normalize path separators for S3
        $s3Key = $relativePath -replace '\\', '/'
        
        Invoke-FileUpload -LocalPath $file.FullName -S3Key $s3Key
    }
}

# Function to delete old files
function Remove-OldFiles {
    if (-not $DeleteOldFiles) {
        Write-Status "🔄 Skipping deletion of old files" -Color "Blue"
        return
    }
    
    Write-Status "🔄 Checking for old files to delete..." -Color "Blue"
    
    try {
        # Get list of current files
        $currentFiles = Get-ChildItem -Path $BuildDir -Recurse -File | 
                       ForEach-Object { 
                           $_.FullName.Substring($BuildDir.Length + 1) -replace '\\', '/' 
                       } | Sort-Object
        
        # Get list of files in S3
        $s3Output = aws s3 ls "s3://$S3WebsiteBucket" --recursive --region $AwsRegion 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Status "⚠️  Could not list existing S3 files" -Color "Yellow"
            return
        }
        
        $s3Files = $s3Output | ForEach-Object {
            if ($_ -match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\s+\d+\s+(.+)$') {
                $matches[1]
            }
        } | Sort-Object
        
        # Find files to delete (in S3 but not in current build)
        $filesToDelete = $s3Files | Where-Object { $_ -notin $currentFiles }
        
        if ($filesToDelete.Count -eq 0) {
            Write-Status "✅ No old files to delete" -Color "Green"
        }
        else {
            Write-Status "🗑️  Deleting $($filesToDelete.Count) old files..." -Color "Yellow"
            
            foreach ($file in $filesToDelete) {
                if ($DryRun) {
                    Write-Status "🔍 [DRY RUN] Would delete: $file" -Color "Yellow"
                }
                else {
                    try {
                        $null = aws s3 rm "s3://$S3WebsiteBucket/$file" --region $AwsRegion --quiet 2>&1
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Status "🗑️  Deleted: $file" -Color "Green"
                        }
                        else {
                            throw "AWS CLI returned exit code $LASTEXITCODE"
                        }
                    }
                    catch {
                        Write-Status "❌ Failed to delete: $file - $($_.Exception.Message)" -Color "Red"
                        $script:ErrorCount++
                        $script:Errors += @{ File = $file; Error = $_.Exception.Message }
                    }
                }
            }
        }
    }
    catch {
        Write-Status "❌ Error during old file cleanup: $($_.Exception.Message)" -Color "Red"
        $script:ErrorCount++
        $script:Errors += @{ Operation = "cleanup"; Error = $_.Exception.Message }
    }
}

# Function to create CloudFront invalidation
function New-CloudFrontInvalidation {
    if (-not $CreateInvalidation -or -not $CloudFrontDistributionId) {
        Write-Status "🔄 Skipping CloudFront invalidation" -Color "Blue"
        return
    }
    
    Write-Status "🔄 Creating CloudFront invalidation..." -Color "Blue"
    
    if ($DryRun) {
        Write-Status "🔍 [DRY RUN] Would create CloudFront invalidation" -Color "Yellow"
        return
    }
    
    try {
        $callerReference = "deployment-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
        
        $result = aws cloudfront create-invalidation `
            --distribution-id $CloudFrontDistributionId `
            --paths "/*" `
            --region $AwsRegion `
            --query "Invalidation.Id" `
            --output text 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Status "✅ CloudFront invalidation created: $result" -Color "Green"
        }
        else {
            throw "AWS CLI returned exit code $LASTEXITCODE"
        }
    }
    catch {
        Write-Status "❌ Failed to create CloudFront invalidation: $($_.Exception.Message)" -Color "Red"
        $script:ErrorCount++
        $script:Errors += @{ Operation = "cloudfront-invalidation"; Error = $_.Exception.Message }
    }
}

# Function to print deployment summary
function Write-Summary {
    Write-Host ""
    Write-Status "📊 Deployment Summary:" -Color "Blue"
    Write-Status "✅ Files uploaded: $UploadedCount" -Color "Green"
    
    if ($ErrorCount -gt 0) {
        Write-Status "❌ Errors: $ErrorCount" -Color "Red"
        Write-Host ""
        Write-Status "❌ Errors encountered:" -Color "Red"
        foreach ($error in $Errors) {
            $identifier = $error.File ?? $error.Operation
            Write-Status "   - $identifier`: $($error.Error)" -Color "Red"
        }
        Write-Host ""
        Write-Status "⚠️  Deployment completed with errors" -Color "Yellow"
        return $false
    }
    else {
        Write-Host ""
        Write-Status "🎉 Deployment completed successfully!" -Color "Green"
        
        if ($CloudFrontDistributionId -and $CreateInvalidation) {
            Write-Status "🌐 Your site will be available at the CloudFront distribution URL" -Color "Blue"
            Write-Status "⏱️  CloudFront invalidation may take 5-15 minutes to complete" -Color "Blue"
        }
        return $true
    }
}

# Main deployment function
function Start-Deployment {
    Write-Status "🚀 Starting Next.js deployment to S3..." -Color "Blue"
    Write-Status "📁 Build directory: $BuildDir" -Color "Blue"
    Write-Status "🪣 S3 bucket: $S3WebsiteBucket" -Color "Blue"
    Write-Status "🌍 Environment: $Environment" -Color "Blue"
    
    if ($DryRun) {
        Write-Status "🔍 DRY RUN MODE - No actual changes will be made" -Color "Yellow"
    }
    
    try {
        # Validate configuration
        Test-Configuration
        
        # Upload files
        Invoke-FilesUpload
        
        # Delete old files
        Remove-OldFiles
        
        # Create CloudFront invalidation
        New-CloudFrontInvalidation
        
        # Print summary and exit with appropriate code
        if (Write-Summary) {
            exit 0
        }
        else {
            exit 1
        }
    }
    catch {
        Write-Status "💥 Deployment failed: $($_.Exception.Message)" -Color "Red"
        exit 1
    }
}

# Handle help parameter
if ($Help) {
    Show-Usage
    exit 0
}

# Start deployment
Start-Deployment