#!/bin/bash

# Bootstrap script to initialize Terraform state infrastructure
# This script creates the S3 bucket and DynamoDB table required for remote state

set -e

echo "🚀 Bootstrapping Terraform state infrastructure..."

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ Error: AWS CLI is not configured or credentials are invalid"
    echo "Please run 'aws configure' to set up your AWS credentials"
    exit 1
fi

# Get current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "📋 Current AWS Account: $(aws sts get-caller-identity --query Account --output text)"
echo "🌍 Current AWS Region: $(aws configure get region)"

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init

# Plan the infrastructure
echo "📝 Planning bootstrap infrastructure..."
terraform plan -out=bootstrap.tfplan

# Ask for confirmation
echo ""
read -p "🤔 Do you want to apply the bootstrap infrastructure? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "✅ Applying bootstrap infrastructure..."
    terraform apply bootstrap.tfplan
    
    echo ""
    echo "🎉 Bootstrap infrastructure created successfully!"
    echo ""
    echo "📊 Resources created:"
    echo "   • S3 Bucket: $(terraform output -raw state_bucket_name)"
    echo "   • DynamoDB Table: $(terraform output -raw dynamodb_table_name)"
    echo ""
    echo "🔄 You can now use Terragrunt to deploy your environments!"
    echo "   • Run 'terragrunt plan' in any environment directory"
    echo "   • Run 'terragrunt apply' to deploy resources"
    
    # Clean up plan file
    rm -f bootstrap.tfplan
else
    echo "❌ Bootstrap cancelled"
    rm -f bootstrap.tfplan
    exit 1
fi