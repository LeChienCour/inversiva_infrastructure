#!/bin/bash

# Simple deployment script for local development
# Usage: ./scripts/deploy.sh [environment] [component] [action]

set -e

# Function to handle lock file synchronization across components
sync_lock_file() {
    local component_dir="$1"
    local component_lock_file=".terraform.lock.hcl"
    local reference_lock_file="../cognito/.terraform.lock.hcl"
    
    # Use cognito component as the reference for lock file consistency
    # If cognito has a lock file and current component doesn't, copy it
    if [ -f "$reference_lock_file" ] && [ ! -f "$component_lock_file" ] && [ "$component_dir" != "cognito" ]; then
        echo -e "${YELLOW}📋 Copying reference lock file to $component_dir...${NC}"
        cp "$reference_lock_file" "$component_lock_file"
    fi
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT=${1:-dev}
COMPONENT=${2:-all}
ACTION=${3:-plan}

echo -e "${BLUE}🚀 Terraform Deployment Script${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "Environment: ${GREEN}$ENVIRONMENT${NC}"
echo -e "Component: ${GREEN}$COMPONENT${NC}"
echo -e "Action: ${GREEN}$ACTION${NC}"
echo -e "Working Directory: ${BLUE}$(pwd)${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform not found. Please install Terraform.${NC}"
    exit 1
fi

if ! command -v terragrunt &> /dev/null; then
    echo -e "${RED}❌ Terragrunt not found. Please install Terragrunt.${NC}"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured. Please run 'aws configure'.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"
echo ""

# Navigate to environment directory (works from any location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_DIR="$PROJECT_ROOT/environments/$ENVIRONMENT"

if [ ! -d "$ENV_DIR" ]; then
    echo -e "${RED}❌ Environment directory '$ENV_DIR' not found${NC}"
    exit 1
fi

echo -e "${YELLOW}📁 Navigating to: $ENV_DIR${NC}"
cd "$ENV_DIR"

# Determine components to deploy
if [ "$COMPONENT" = "all" ]; then
    COMPONENTS="cognito s3-website s3-content route53-acm cloudfront monitoring"
else
    COMPONENTS="$COMPONENT"
fi

echo -e "${YELLOW}🔧 Components to process: $COMPONENTS${NC}"
echo ""

# Process each component
for comp in $COMPONENTS; do
    if [ ! -d "$comp" ]; then
        echo -e "${YELLOW}⚠️ Component '$comp' not found, skipping...${NC}"
        continue
    fi
    
    echo -e "${BLUE}📦 Processing component: $comp${NC}"
    cd "$comp"
    
    # Sync lock file before initialization
    sync_lock_file "$comp"
    
    # Initialize with proper lock file handling
    echo -e "${YELLOW}🔄 Initializing...${NC}"
    
    # Remove local .terraform directory to ensure clean state
    if [ -d ".terraform" ]; then
        echo -e "${YELLOW}🧹 Cleaning local .terraform directory...${NC}"
        rm -rf .terraform
    fi
    
    # Initialize with upgrade to ensure provider versions are consistent
    terragrunt init --terragrunt-non-interactive -upgrade
    
    # Validate configuration
    echo -e "${YELLOW}🔍 Validating configuration...${NC}"
    terragrunt validate --terragrunt-non-interactive
    
    # Perform action
    case $ACTION in
        "plan")
            echo -e "${YELLOW}📋 Planning...${NC}"
            terragrunt plan --terragrunt-non-interactive
            ;;
        "apply")
            echo -e "${YELLOW}🚀 Applying...${NC}"
            terragrunt apply --terragrunt-non-interactive -auto-approve
            ;;
        "destroy")
            echo -e "${YELLOW}🗑️ Destroying...${NC}"
            terragrunt destroy --terragrunt-non-interactive -auto-approve
            ;;
        "output")
            echo -e "${YELLOW}📤 Getting outputs...${NC}"
            terragrunt output --terragrunt-non-interactive
            ;;
        "refresh")
            echo -e "${YELLOW}🔄 Refreshing state...${NC}"
            terragrunt refresh --terragrunt-non-interactive
            ;;
        "init-only")
            echo -e "${YELLOW}🔧 Initialize only (no other actions)...${NC}"
            # Already initialized above, just validate
            ;;
        *)
            echo -e "${RED}❌ Unknown action: $ACTION${NC}"
            echo -e "${YELLOW}Available actions: plan, apply, destroy, output, refresh, init-only${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}✅ Component '$comp' completed${NC}"
    cd ..
    echo ""
done

echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo -e "${BLUE}Environment: $ENVIRONMENT${NC}"
echo -e "${BLUE}Action: $ACTION${NC}"
echo -e "${BLUE}Components: $COMPONENTS${NC}"