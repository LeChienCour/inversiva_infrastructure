#!/bin/bash

# Shell deployment script for Next.js build artifacts to S3
# Uploads the Next.js build output to the S3 website bucket

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration with defaults
AWS_REGION=${AWS_REGION:-"us-east-1"}
S3_WEBSITE_BUCKET=${S3_WEBSITE_BUCKET}
CLOUDFRONT_DISTRIBUTION_ID=${CLOUDFRONT_DISTRIBUTION_ID}
BUILD_DIR=${BUILD_DIR:-".next/out"}
ENVIRONMENT=${ENVIRONMENT:-"dev"}
DELETE_OLD_FILES=${DELETE_OLD_FILES:-"false"}
CREATE_INVALIDATION=${CREATE_INVALIDATION:-"true"}
DRY_RUN=${DRY_RUN:-"false"}

# Cache control settings
CACHE_CONTROL_HTML="public, max-age=0, s-maxage=86400, must-revalidate"
CACHE_CONTROL_ASSETS="public, max-age=31536000, immutable"
CACHE_CONTROL_API="public, max-age=0, s-maxage=60"
CACHE_CONTROL_DEFAULT="public, max-age=86400"

# Counters
UPLOADED_COUNT=0
ERROR_COUNT=0

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to validate configuration
validate_config() {
    print_status $BLUE "🔄 Validating configuration..."
    
    if [ -z "$S3_WEBSITE_BUCKET" ]; then
        print_status $RED "❌ S3_WEBSITE_BUCKET environment variable is required"
        exit 1
    fi
    
    if [ ! -d "$BUILD_DIR" ]; then
        print_status $RED "❌ Build directory not found: $BUILD_DIR"
        exit 1
    fi
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_status $RED "❌ AWS CLI is not installed or not in PATH"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_status $RED "❌ AWS credentials not configured or invalid"
        exit 1
    fi
    
    print_status $GREEN "✅ Configuration validated"
}

# Function to get appropriate cache control header
get_cache_control() {
    local file_path=$1
    
    if [[ $file_path == *.html ]]; then
        echo "$CACHE_CONTROL_HTML"
    elif [[ $file_path == *"/_next/static/"* ]]; then
        echo "$CACHE_CONTROL_ASSETS"
    elif [[ $file_path == api/* ]]; then
        echo "$CACHE_CONTROL_API"
    else
        echo "$CACHE_CONTROL_DEFAULT"
    fi
}

# Function to get content type
get_content_type() {
    local file_path=$1
    local extension="${file_path##*.}"
    
    case $extension in
        html) echo "text/html; charset=utf-8" ;;
        js) echo "application/javascript; charset=utf-8" ;;
        css) echo "text/css; charset=utf-8" ;;
        json) echo "application/json; charset=utf-8" ;;
        png) echo "image/png" ;;
        jpg|jpeg) echo "image/jpeg" ;;
        gif) echo "image/gif" ;;
        svg) echo "image/svg+xml" ;;
        ico) echo "image/x-icon" ;;
        pdf) echo "application/pdf" ;;
        txt) echo "text/plain; charset=utf-8" ;;
        xml) echo "application/xml; charset=utf-8" ;;
        woff) echo "font/woff" ;;
        woff2) echo "font/woff2" ;;
        ttf) echo "font/ttf" ;;
        eot) echo "application/vnd.ms-fontobject" ;;
        *) echo "application/octet-stream" ;;
    esac
}

# Function to upload a single file
upload_file() {
    local local_path=$1
    local s3_key=$2
    local cache_control=$(get_cache_control "$s3_key")
    local content_type=$(get_content_type "$s3_key")
    local file_size=$(stat -f%z "$local_path" 2>/dev/null || stat -c%s "$local_path" 2>/dev/null || echo "unknown")
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status $YELLOW "🔍 [DRY RUN] Would upload: $s3_key"
        ((UPLOADED_COUNT++))
        return 0
    fi
    
    # Upload file with metadata
    if aws s3 cp "$local_path" "s3://$S3_WEBSITE_BUCKET/$s3_key" \
        --region "$AWS_REGION" \
        --cache-control "$cache_control" \
        --content-type "$content_type" \
        --metadata "deployment-environment=$ENVIRONMENT,deployment-timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --quiet; then
        
        print_status $GREEN "✅ Uploaded: $s3_key ($file_size bytes)"
        ((UPLOADED_COUNT++))
    else
        print_status $RED "❌ Failed to upload: $s3_key"
        ((ERROR_COUNT++))
    fi
}

# Function to upload all files
upload_files() {
    print_status $BLUE "🔄 Scanning build directory..."
    
    local file_count=0
    while IFS= read -r -d '' file; do
        ((file_count++))
    done < <(find "$BUILD_DIR" -type f -print0)
    
    print_status $BLUE "📄 Found $file_count files to upload"
    print_status $BLUE "🔄 Uploading files..."
    
    # Upload files
    while IFS= read -r -d '' file; do
        local relative_path=${file#$BUILD_DIR/}
        # Normalize path separators for S3
        local s3_key=${relative_path//\\//}
        upload_file "$file" "$s3_key"
    done < <(find "$BUILD_DIR" -type f -print0)
}

# Function to delete old files
delete_old_files() {
    if [ "$DELETE_OLD_FILES" != "true" ]; then
        print_status $BLUE "🔄 Skipping deletion of old files"
        return 0
    fi
    
    print_status $BLUE "🔄 Checking for old files to delete..."
    
    # Get list of current files
    local current_files=$(mktemp)
    find "$BUILD_DIR" -type f -exec basename {} \; | sort > "$current_files"
    
    # Get list of files in S3
    local s3_files=$(mktemp)
    if aws s3 ls "s3://$S3_WEBSITE_BUCKET" --recursive --region "$AWS_REGION" | awk '{print $4}' | sort > "$s3_files"; then
        # Find files to delete (in S3 but not in current build)
        local files_to_delete=$(mktemp)
        comm -23 "$s3_files" "$current_files" > "$files_to_delete"
        
        local delete_count=$(wc -l < "$files_to_delete")
        
        if [ "$delete_count" -eq 0 ]; then
            print_status $GREEN "✅ No old files to delete"
        else
            print_status $YELLOW "🗑️  Deleting $delete_count old files..."
            
            while IFS= read -r file; do
                if [ -n "$file" ]; then
                    if [ "$DRY_RUN" = "true" ]; then
                        print_status $YELLOW "🔍 [DRY RUN] Would delete: $file"
                    else
                        if aws s3 rm "s3://$S3_WEBSITE_BUCKET/$file" --region "$AWS_REGION" --quiet; then
                            print_status $GREEN "🗑️  Deleted: $file"
                        else
                            print_status $RED "❌ Failed to delete: $file"
                            ((ERROR_COUNT++))
                        fi
                    fi
                fi
            done < "$files_to_delete"
        fi
        
        # Cleanup temp files
        rm -f "$files_to_delete"
    else
        print_status $YELLOW "⚠️  Could not list existing S3 files"
    fi
    
    # Cleanup temp files
    rm -f "$current_files" "$s3_files"
}

# Function to create CloudFront invalidation
create_invalidation() {
    if [ "$CREATE_INVALIDATION" != "true" ] || [ -z "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
        print_status $BLUE "🔄 Skipping CloudFront invalidation"
        return 0
    fi
    
    print_status $BLUE "🔄 Creating CloudFront invalidation..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status $YELLOW "🔍 [DRY RUN] Would create CloudFront invalidation"
        return 0
    fi
    
    local caller_reference="deployment-$(date +%s)"
    
    if aws cloudfront create-invalidation \
        --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
        --paths "/*" \
        --region "$AWS_REGION" \
        --query 'Invalidation.Id' \
        --output text > /dev/null; then
        
        print_status $GREEN "✅ CloudFront invalidation created"
    else
        print_status $RED "❌ Failed to create CloudFront invalidation"
        ((ERROR_COUNT++))
    fi
}

# Function to print deployment summary
print_summary() {
    echo
    print_status $BLUE "📊 Deployment Summary:"
    print_status $GREEN "✅ Files uploaded: $UPLOADED_COUNT"
    
    if [ $ERROR_COUNT -gt 0 ]; then
        print_status $RED "❌ Errors: $ERROR_COUNT"
        print_status $YELLOW "⚠️  Deployment completed with errors"
        return 1
    else
        print_status $GREEN "🎉 Deployment completed successfully!"
        
        if [ -n "$CLOUDFRONT_DISTRIBUTION_ID" ] && [ "$CREATE_INVALIDATION" = "true" ]; then
            print_status $BLUE "🌐 Your site will be available at the CloudFront distribution URL"
            print_status $BLUE "⏱️  CloudFront invalidation may take 5-15 minutes to complete"
        fi
        return 0
    fi
}

# Main deployment function
main() {
    print_status $BLUE "🚀 Starting Next.js deployment to S3..."
    print_status $BLUE "📁 Build directory: $BUILD_DIR"
    print_status $BLUE "🪣 S3 bucket: $S3_WEBSITE_BUCKET"
    print_status $BLUE "🌍 Environment: $ENVIRONMENT"
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status $YELLOW "🔍 DRY RUN MODE - No actual changes will be made"
    fi
    
    # Validate configuration
    validate_config
    
    # Upload files
    upload_files
    
    # Delete old files
    delete_old_files
    
    # Create CloudFront invalidation
    create_invalidation
    
    # Print summary and exit with appropriate code
    if print_summary; then
        exit 0
    else
        exit 1
    fi
}

# Show usage information
show_usage() {
    echo "Usage: $0 [options]"
    echo
    echo "Environment Variables:"
    echo "  AWS_REGION                    AWS region (default: us-east-1)"
    echo "  S3_WEBSITE_BUCKET            S3 bucket name for website hosting (required)"
    echo "  CLOUDFRONT_DISTRIBUTION_ID   CloudFront distribution ID (optional)"
    echo "  BUILD_DIR                    Build directory path (default: .next/out)"
    echo "  ENVIRONMENT                  Deployment environment (default: dev)"
    echo "  DELETE_OLD_FILES             Delete old files not in current build (default: false)"
    echo "  CREATE_INVALIDATION          Create CloudFront invalidation (default: true)"
    echo "  DRY_RUN                      Show what would be done without making changes (default: false)"
    echo
    echo "Examples:"
    echo "  # Basic deployment"
    echo "  S3_WEBSITE_BUCKET=my-website-bucket $0"
    echo
    echo "  # Production deployment with CloudFront"
    echo "  S3_WEBSITE_BUCKET=my-website-bucket \\"
    echo "  CLOUDFRONT_DISTRIBUTION_ID=E1234567890123 \\"
    echo "  ENVIRONMENT=prod \\"
    echo "  DELETE_OLD_FILES=true \\"
    echo "  $0"
    echo
    echo "  # Dry run to see what would be deployed"
    echo "  S3_WEBSITE_BUCKET=my-website-bucket DRY_RUN=true $0"
}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        show_usage
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac