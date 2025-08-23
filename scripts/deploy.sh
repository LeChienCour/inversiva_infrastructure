#!/bin/bash

# Pure Terraform deployment script for local development
# Usage: ./scripts/deploy.sh [environment] [action]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT=${1:-dev}
ACTION=${2:-plan}

echo -e "${BLUE}🚀 Pure Terraform Deployment Script${NC}"
echo -e "${BLUE}====================================${NC}"
echo -e "Environment: ${GREEN}$ENVIRONMENT${NC}"
echo -e "Action: ${GREEN}$ACTION${NC}"
echo -e "Working Directory: ${BLUE}$(pwd)${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform not found. Please install Terraform.${NC}"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured. Please run 'aws configure'.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"
echo ""

# Function to validate deployment prerequisites
validate_deployment_prerequisites() {
    local environment=$1
    local action=$2
    
    echo -e "${YELLOW}🔍 Validating deployment prerequisites...${NC}"
    
    # Validate environment parameter
    if [[ ! "$environment" =~ ^(dev|prod)$ ]]; then
        echo -e "${RED}❌ Invalid environment: $environment${NC}"
        echo -e "${YELLOW}💡 Valid environments: dev, prod${NC}"
        return 1
    fi
    
    # Validate action parameter
    local valid_actions=("plan" "apply" "destroy" "output" "refresh" "init-only")
    local action_valid=false
    for valid_action in "${valid_actions[@]}"; do
        if [ "$action" = "$valid_action" ]; then
            action_valid=true
            break
        fi
    done
    
    if [ "$action_valid" = false ]; then
        echo -e "${RED}❌ Invalid action: $action${NC}"
        echo -e "${YELLOW}💡 Valid actions: ${valid_actions[*]}${NC}"
        return 1
    fi
    
    # Additional validation for destructive actions
    if [ "$action" = "destroy" ]; then
        echo -e "${YELLOW}⚠️ Destructive action detected: $action${NC}"
        if [ "$environment" = "prod" ]; then
            echo -e "${RED}⚠️ WARNING: You are about to destroy PRODUCTION infrastructure!${NC}"
        fi
    fi
    
    # Additional validation for production apply
    if [ "$action" = "apply" ] && [ "$environment" = "prod" ]; then
        echo -e "${YELLOW}⚠️ Production deployment detected${NC}"
        echo -e "${YELLOW}💡 Ensure you have reviewed the plan before applying${NC}"
    fi
    
    echo -e "${GREEN}✅ Deployment prerequisites validated${NC}"
    return 0
}

# Validate deployment prerequisites
if ! validate_deployment_prerequisites "$ENVIRONMENT" "$ACTION"; then
    exit 1
fi

# Get script and project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_DIR="$PROJECT_ROOT/environments/$ENVIRONMENT"

# Load environment variables and perform validation
echo -e "${YELLOW}📋 Loading and validating environment configuration...${NC}"
if ! source "$SCRIPT_DIR/load-env.sh" "$ENVIRONMENT"; then
    echo -e "${RED}❌ Environment configuration validation failed${NC}"
    echo -e "${YELLOW}💡 Please check the following:${NC}"
    echo -e "${YELLOW}   - Verify config/${ENVIRONMENT}.env exists and is properly formatted${NC}"
    echo -e "${YELLOW}   - Ensure all required environment variables are set${NC}"
    echo -e "${YELLOW}   - Check AWS credentials are configured (aws configure)${NC}"
    echo -e "${YELLOW}   - Verify Terraform is installed and accessible${NC}"
    exit 1
fi

# Check if environment directory exists
if [ ! -d "$ENV_DIR" ]; then
    echo -e "${RED}❌ Environment directory '$ENV_DIR' not found${NC}"
    exit 1
fi

echo -e "${YELLOW}📁 Navigating to: $ENV_DIR${NC}"
cd "$ENV_DIR"

# Generate terraform.tfvars from environment variables
echo -e "${YELLOW}📝 Generating terraform.tfvars...${NC}"
if ! generate_terraform_tfvars "." "$ENVIRONMENT"; then
    echo -e "${RED}❌ Failed to generate terraform.tfvars${NC}"
    echo -e "${YELLOW}💡 This may indicate missing or invalid environment variables${NC}"
    exit 1
fi

# Validate generated terraform.tfvars
echo -e "${YELLOW}🔍 Validating generated terraform.tfvars...${NC}"
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}❌ terraform.tfvars file was not created${NC}"
    exit 1
fi

# Check if terraform.tfvars has content
if [ ! -s "terraform.tfvars" ]; then
    echo -e "${RED}❌ terraform.tfvars file is empty${NC}"
    exit 1
fi

echo -e "${GREEN}✅ terraform.tfvars generated and validated successfully${NC}"

# Initialize Terraform
echo -e "${YELLOW}🔄 Initializing Terraform...${NC}"

# Remove local .terraform directory to ensure clean state
if [ -d ".terraform" ]; then
    echo -e "${YELLOW}🧹 Cleaning local .terraform directory...${NC}"
    rm -rf .terraform
fi

# Initialize with upgrade to ensure provider versions are consistent
if ! terraform init -upgrade; then
    echo -e "${RED}❌ Terraform initialization failed${NC}"
    echo -e "${YELLOW}💡 Common causes:${NC}"
    echo -e "${YELLOW}   - Invalid backend configuration${NC}"
    echo -e "${YELLOW}   - Network connectivity issues${NC}"
    echo -e "${YELLOW}   - Invalid AWS credentials${NC}"
    echo -e "${YELLOW}   - Missing S3 bucket or DynamoDB table for state management${NC}"
    exit 1
fi

# Validate configuration
echo -e "${YELLOW}🔍 Validating Terraform configuration...${NC}"
if ! terraform validate; then
    echo -e "${RED}❌ Terraform configuration validation failed${NC}"
    echo -e "${YELLOW}💡 Please check your Terraform files for syntax errors${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Terraform initialization and validation completed${NC}"

# Perform action
case $ACTION in
    "plan")
        echo -e "${YELLOW}📋 Planning infrastructure changes...${NC}"
        if ! terraform plan; then
            echo -e "${RED}❌ Terraform plan failed${NC}"
            echo -e "${YELLOW}💡 Please check the error messages above${NC}"
            exit 1
        fi
        ;;
    "apply")
        echo -e "${YELLOW}🚀 Applying infrastructure changes...${NC}"
        if [ "$ENVIRONMENT" = "prod" ]; then
            echo -e "${YELLOW}⚠️ Production deployment requires confirmation${NC}"
            read -p "Are you sure you want to apply changes to production? (yes/no): " confirm
            if [ "$confirm" != "yes" ]; then
                echo -e "${YELLOW}❌ Deployment cancelled by user${NC}"
                exit 0
            fi
        fi
        
        if ! terraform apply -auto-approve; then
            echo -e "${RED}❌ Terraform apply failed${NC}"
            echo -e "${YELLOW}💡 Infrastructure may be in an inconsistent state${NC}"
            echo -e "${YELLOW}💡 Review the error messages and run 'terraform plan' to assess the situation${NC}"
            exit 1
        fi
        ;;
    "destroy")
        echo -e "${YELLOW}🗑️ Destroying infrastructure...${NC}"
        echo -e "${RED}⚠️ WARNING: This will destroy all infrastructure in the $ENVIRONMENT environment!${NC}"
        read -p "Are you sure you want to destroy the $ENVIRONMENT environment? Type 'destroy' to confirm: " confirm
        if [ "$confirm" != "destroy" ]; then
            echo -e "${YELLOW}❌ Destroy operation cancelled${NC}"
            exit 0
        fi
        
        if ! terraform destroy -auto-approve; then
            echo -e "${RED}❌ Terraform destroy failed${NC}"
            echo -e "${YELLOW}💡 Some resources may still exist${NC}"
            echo -e "${YELLOW}💡 Review the error messages and manually clean up if necessary${NC}"
            exit 1
        fi
        ;;
    "output")
        echo -e "${YELLOW}📤 Getting infrastructure outputs...${NC}"
        if ! terraform output; then
            echo -e "${RED}❌ Failed to get Terraform outputs${NC}"
            echo -e "${YELLOW}💡 This may indicate that no infrastructure has been deployed yet${NC}"
            exit 1
        fi
        ;;
    "refresh")
        echo -e "${YELLOW}🔄 Refreshing Terraform state...${NC}"
        if ! terraform refresh; then
            echo -e "${RED}❌ Terraform refresh failed${NC}"
            echo -e "${YELLOW}💡 State file may be corrupted or inaccessible${NC}"
            exit 1
        fi
        ;;
    "init-only")
        echo -e "${YELLOW}🔧 Initialization completed (no other actions performed)${NC}"
        # Already initialized above, just validate
        ;;
    *)
        echo -e "${RED}❌ Unknown action: $ACTION${NC}"
        echo -e "${YELLOW}💡 Available actions: plan, apply, destroy, output, refresh, init-only${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo -e "${BLUE}Environment: $ENVIRONMENT${NC}"
echo -e "${BLUE}Action: $ACTION${NC}"