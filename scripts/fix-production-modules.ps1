# Fix Production Modules Script
# This script removes the root include from all production modules to fix circular dependency issues

param(
    [switch]$Help,
    [switch]$DryRun
)

# Show help if requested
if ($Help) {
    Write-Host @"
Fix Production Modules Script

This script removes the root include from all production modules to fix circular dependency issues.

Usage:
    .\fix-production-modules.ps1 [-Help] [-DryRun]

Parameters:
    -Help            Show this help message
    -DryRun          Show what would be changed without making changes

Examples:
    # Show what would be changed
    .\fix-production-modules.ps1 -DryRun

    # Apply the fixes
    .\fix-production-modules.ps1
"@
    exit 0
}

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to fix a single module file
function Fix-ModuleFile {
    param(
        [string]$FilePath,
        [bool]$DryRun
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-ColorOutput "  ⚠️  File not found: $FilePath" "Yellow"
        return $false
    }
    
    $content = Get-Content $FilePath -Raw
    $originalContent = $content
    
    # Remove root include block
    $content = $content -replace '(?s)# Include the root terragrunt configuration.*?}\s*\n', ''
    
    # Fix local references to use include.env.locals
    $content = $content -replace 'local\.prod_config\.', 'include.env.locals.prod_config.'
    
    # Check if changes were made
    if ($content -eq $originalContent) {
        Write-ColorOutput "  ✅ No changes needed" "Green"
        return $false
    }
    
    if ($DryRun) {
        Write-ColorOutput "  📝 Would modify file" "Yellow"
        return $true
    } else {
        try {
            Set-Content -Path $FilePath -Value $content -NoNewline
            Write-ColorOutput "  ✅ Fixed file" "Green"
            return $true
        } catch {
            Write-ColorOutput "  ❌ Error fixing file: $($_.Exception.Message)" "Red"
            return $false
        }
    }
}

# Main execution
try {
    Write-ColorOutput "=== Fix Production Modules Script ===" "Cyan"
    
    if ($DryRun) {
        Write-ColorOutput "DRY RUN MODE - No changes will be made" "Yellow"
    }
    
    Write-ColorOutput ""
    
    # Define all production modules
    $modules = @(
        @{ Path = "environments/prod/s3-website/terragrunt.hcl"; Name = "S3 Website" },
        @{ Path = "environments/prod/s3-content/terragrunt.hcl"; Name = "S3 Content" },
        @{ Path = "environments/prod/cloudfront/terragrunt.hcl"; Name = "CloudFront" },
        @{ Path = "environments/prod/route53-acm/terragrunt.hcl"; Name = "Route53 and ACM" },
        @{ Path = "environments/prod/monitoring/terragrunt.hcl"; Name = "Monitoring" }
    )
    
    $totalFiles = $modules.Count
    $modifiedFiles = 0
    
    Write-ColorOutput "Processing $totalFiles production modules..." "White"
    Write-ColorOutput ""
    
    foreach ($module in $modules) {
        Write-ColorOutput "Processing $($module.Name)..." "Yellow"
        $wasModified = Fix-ModuleFile -FilePath $module.Path -DryRun $DryRun
        if ($wasModified) {
            $modifiedFiles++
        }
        Write-ColorOutput ""
    }
    
    # Summary
    Write-ColorOutput "=== Summary ===" "Cyan"
    Write-ColorOutput "Total modules processed: $totalFiles" "White"
    
    if ($DryRun) {
        Write-ColorOutput "Files that would be modified: $modifiedFiles" "Yellow"
        Write-ColorOutput ""
        Write-ColorOutput "To apply these changes, run the script without -DryRun" "White"
    } else {
        Write-ColorOutput "Files modified: $modifiedFiles" "Green"
        Write-ColorOutput ""
        Write-ColorOutput "All production modules have been fixed!" "Green"
        Write-ColorOutput "You can now run: terragrunt run-all plan --terragrunt-working-dir environments/prod" "White"
    }
    
} catch {
    Write-ColorOutput "ERROR: Script execution failed: $($_.Exception.Message)" "Red"
    exit 1
}
