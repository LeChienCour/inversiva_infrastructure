#!/bin/bash

# Presigned URL Utility Script for S3 Content Bucket
# This script provides utilities for generating and testing presigned URLs

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_ENVIRONMENT="dev"
DEFAULT_EXPIRATION=900  # 15 minutes
DEFAULT_REGION="us-east-1"

# Help function
show_help() {
    cat << EOF
Presigned URL Utility Script

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    generate    Generate a presigned URL for an S3 object
    test        Test a presigned URL by attempting to access it
    upload      Upload a file and generate a presigned URL
    list        List objects in the content bucket
    help        Show this help message

OPTIONS:
    -e, --environment ENV    Environment (dev/prod) [default: $DEFAULT_ENVIRONMENT]
    -b, --bucket BUCKET      S3 bucket name (auto-detected if not provided)
    -k, --key KEY           S3 object key
    -f, --file FILE         Local file path
    -t, --expiration TIME   Expiration time in seconds [default: $DEFAULT_EXPIRATION]
    -r, --region REGION     AWS region [default: $DEFAULT_REGION]
    -u, --url URL           Presigned URL to test
    -v, --verbose           Verbose output

EXAMPLES:
    # Generate presigned URL for existing object
    $0 generate -e dev -k "users/user123/document.pdf"
    
    # Upload file and generate presigned URL
    $0 upload -e dev -f "./test-file.txt" -k "users/user123/test-file.txt"
    
    # Test a presigned URL
    $0 test -u "https://bucket.s3.amazonaws.com/object?..."
    
    # List objects in bucket
    $0 list -e prod

EOF
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get bucket name from Terragrunt outputs
get_bucket_name() {
    local environment=$1
    local bucket_name=""
    
    if [ -d "$PROJECT_ROOT/environments/$environment/s3-content" ]; then
        cd "$PROJECT_ROOT/environments/$environment/s3-content"
        bucket_name=$(terragrunt output -raw bucket_name 2>/dev/null || echo "")
    fi
    
    if [ -z "$bucket_name" ]; then
        log_error "Could not retrieve bucket name for environment: $environment"
        log_info "Make sure the infrastructure is deployed and Terragrunt outputs are available"
        return 1
    fi
    
    echo "$bucket_name"
}

# Check if AWS CLI is configured
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed or not in PATH"
        return 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI is not configured or credentials are invalid"
        log_info "Run 'aws configure' to set up your credentials"
        return 1
    fi
    
    log_info "AWS CLI is configured and ready"
}

# Generate presigned URL
generate_presigned_url() {
    local environment=$1
    local bucket_name=$2
    local object_key=$3
    local expiration=$4
    local verbose=$5
    
    if [ -z "$bucket_name" ]; then
        bucket_name=$(get_bucket_name "$environment")
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi
    
    log_info "Generating presigned URL..."
    log_info "Environment: $environment"
    log_info "Bucket: $bucket_name"
    log_info "Object Key: $object_key"
    log_info "Expiration: $expiration seconds"
    
    # Check if object exists
    if ! aws s3api head-object --bucket "$bucket_name" --key "$object_key" &> /dev/null; then
        log_warning "Object does not exist: s3://$bucket_name/$object_key"
        log_info "You can upload it first using the 'upload' command"
    fi
    
    # Generate presigned URL
    local presigned_url
    presigned_url=$(aws s3 presign "s3://$bucket_name/$object_key" --expires-in "$expiration")
    
    if [ $? -eq 0 ]; then
        log_success "Presigned URL generated successfully!"
        echo ""
        echo "URL: $presigned_url"
        echo ""
        log_info "This URL will expire in $expiration seconds ($(date -d "+$expiration seconds" 2>/dev/null || date -v "+${expiration}S" 2>/dev/null || echo "$(($expiration/60)) minutes"))"
        
        if [ "$verbose" = "true" ]; then
            echo ""
            echo "Test with curl:"
            echo "curl -I \"$presigned_url\""
        fi
    else
        log_error "Failed to generate presigned URL"
        return 1
    fi
}

# Test presigned URL
test_presigned_url() {
    local url=$1
    local verbose=$2
    
    log_info "Testing presigned URL..."
    
    if [ "$verbose" = "true" ]; then
        log_info "URL: $url"
    fi
    
    # Test with HEAD request first
    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" -I "$url")
    
    if [ "$response_code" = "200" ]; then
        log_success "Presigned URL is valid and accessible (HTTP $response_code)"
        
        # Get additional info
        local content_length
        local content_type
        content_length=$(curl -s -I "$url" | grep -i "content-length" | cut -d' ' -f2 | tr -d '\r')
        content_type=$(curl -s -I "$url" | grep -i "content-type" | cut -d' ' -f2 | tr -d '\r')
        
        if [ -n "$content_length" ]; then
            log_info "Content Length: $content_length bytes"
        fi
        if [ -n "$content_type" ]; then
            log_info "Content Type: $content_type"
        fi
        
    elif [ "$response_code" = "403" ]; then
        log_error "Access denied (HTTP $response_code) - URL may be expired or invalid"
        return 1
    elif [ "$response_code" = "404" ]; then
        log_error "Object not found (HTTP $response_code)"
        return 1
    else
        log_error "Unexpected response code: $response_code"
        return 1
    fi
}

# Upload file and generate presigned URL
upload_and_generate() {
    local environment=$1
    local bucket_name=$2
    local local_file=$3
    local object_key=$4
    local expiration=$5
    local verbose=$6
    
    if [ ! -f "$local_file" ]; then
        log_error "Local file does not exist: $local_file"
        return 1
    fi
    
    if [ -z "$bucket_name" ]; then
        bucket_name=$(get_bucket_name "$environment")
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi
    
    log_info "Uploading file to S3..."
    log_info "Local file: $local_file"
    log_info "S3 location: s3://$bucket_name/$object_key"
    
    # Upload file
    if aws s3 cp "$local_file" "s3://$bucket_name/$object_key"; then
        log_success "File uploaded successfully!"
        
        # Generate presigned URL
        generate_presigned_url "$environment" "$bucket_name" "$object_key" "$expiration" "$verbose"
    else
        log_error "Failed to upload file"
        return 1
    fi
}

# List objects in bucket
list_objects() {
    local environment=$1
    local bucket_name=$2
    local verbose=$3
    
    if [ -z "$bucket_name" ]; then
        bucket_name=$(get_bucket_name "$environment")
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi
    
    log_info "Listing objects in bucket: $bucket_name"
    
    if [ "$verbose" = "true" ]; then
        aws s3 ls "s3://$bucket_name" --recursive --human-readable --summarize
    else
        aws s3 ls "s3://$bucket_name" --recursive
    fi
}

# Main function
main() {
    local command=""
    local environment="$DEFAULT_ENVIRONMENT"
    local bucket_name=""
    local object_key=""
    local local_file=""
    local expiration="$DEFAULT_EXPIRATION"
    local region="$DEFAULT_REGION"
    local url=""
    local verbose="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            generate|test|upload|list|help)
                command="$1"
                shift
                ;;
            -e|--environment)
                environment="$2"
                shift 2
                ;;
            -b|--bucket)
                bucket_name="$2"
                shift 2
                ;;
            -k|--key)
                object_key="$2"
                shift 2
                ;;
            -f|--file)
                local_file="$2"
                shift 2
                ;;
            -t|--expiration)
                expiration="$2"
                shift 2
                ;;
            -r|--region)
                region="$2"
                shift 2
                ;;
            -u|--url)
                url="$2"
                shift 2
                ;;
            -v|--verbose)
                verbose="true"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Show help if no command provided
    if [ -z "$command" ]; then
        show_help
        exit 0
    fi
    
    # Set AWS region
    export AWS_DEFAULT_REGION="$region"
    
    # Check AWS CLI
    if ! check_aws_cli; then
        exit 1
    fi
    
    # Execute command
    case $command in
        generate)
            if [ -z "$object_key" ]; then
                log_error "Object key is required for generate command"
                log_info "Use -k or --key to specify the S3 object key"
                exit 1
            fi
            generate_presigned_url "$environment" "$bucket_name" "$object_key" "$expiration" "$verbose"
            ;;
        test)
            if [ -z "$url" ]; then
                log_error "URL is required for test command"
                log_info "Use -u or --url to specify the presigned URL to test"
                exit 1
            fi
            test_presigned_url "$url" "$verbose"
            ;;
        upload)
            if [ -z "$local_file" ] || [ -z "$object_key" ]; then
                log_error "Both local file and object key are required for upload command"
                log_info "Use -f or --file to specify the local file"
                log_info "Use -k or --key to specify the S3 object key"
                exit 1
            fi
            upload_and_generate "$environment" "$bucket_name" "$local_file" "$object_key" "$expiration" "$verbose"
            ;;
        list)
            list_objects "$environment" "$bucket_name" "$verbose"
            ;;
        help)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"