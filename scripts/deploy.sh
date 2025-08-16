#!/bin/bash

# Simple deployment script for local development
# Usage: ./scripts/deploy.sh [environment] [component] [action]

set -e

# Function to handle lock file synchronization
sync_lock_file() {
    local component_dir="$1"
    local root_lock_file="../../.terraform.lock.hcl"
    local component_lock_file=".terraform.lock.hcl"
    
    # If root lock file exists and component doesn't have one, copy it
    if [ -f "$root_lock_file" ] && [ ! -f "$component_lock_file" ]; then
        echo -e "${YELLOW}📋 Copying root lock file to component...${NC}"
        cp "$root_lock_file" "$component_lock_file"
    fi
    
    # If component has a lock file but root doesn't, copy it up
    if [ -f "$component_lock_file" ] && [ ! -f "$root_lock_file" ]; then
        echo -e "${YELLOW}📋 Copying component lock file to root...${NC}"
        cp "$component_lock_file" "$root_lock_file"
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

# Navigate to environment directory
ENV_DIR="environments/$ENVIRONMENT"
if [ ! -d "$ENV_DIR" ]; then
    echo -e "${RED}❌ Environment directory '$ENV_DIR' not found${NC}"
    exit 1
fi

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