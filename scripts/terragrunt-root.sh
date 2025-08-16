#!/bin/bash

# Root-level Terragrunt orchestration script
# Usage: ./scripts/terragrunt-root.sh [environment] [action]
# Examples:
#   ./scripts/terragrunt-root.sh dev plan
#   ./scripts/terragrunt-root.sh prod apply

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

echo -e "${BLUE}🚀 Root Terragrunt Orchestration${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "Environment: ${GREEN}$ENVIRONMENT${NC}"
echo -e "Action: ${GREEN}$ACTION${NC}"
echo -e "Working from: ${BLUE}$(pwd)${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

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

# Validate environment directory exists
ENV_DIR="environments/$ENVIRONMENT"
if [ ! -d "$ENV_DIR" ]; then
    echo -e "${RED}❌ Environment directory '$ENV_DIR' not found${NC}"
    exit 1
fi

# Execute terragrunt run-all from root
echo -e "${YELLOW}🔧 Executing terragrunt run-all $ACTION for $ENVIRONMENT environment...${NC}"
echo ""

case $ACTION in
    "plan")
        terragrunt run-all plan --terragrunt-working-dir "$ENV_DIR" --terragrunt-non-interactive
        ;;
    "apply")
        echo -e "${YELLOW}⚠️  This will apply changes to your infrastructure. Continue? (y/N)${NC}"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            terragrunt run-all apply --terragrunt-working-dir "$ENV_DIR" --terragrunt-non-interactive
        else
            echo -e "${YELLOW}❌ Apply cancelled by user${NC}"
            exit 0
        fi
        ;;
    "destroy")
        echo -e "${RED}⚠️  This will DESTROY your infrastructure. Type 'yes' to confirm:${NC}"
        read -r response
        if [[ "$response" == "yes" ]]; then
            terragrunt run-all destroy --terragrunt-working-dir "$ENV_DIR" --terragrunt-non-interactive
        else
            echo -e "${YELLOW}❌ Destroy cancelled by user${NC}"
            exit 0
        fi
        ;;
    "output")
        terragrunt run-all output --terragrunt-working-dir "$ENV_DIR" --terragrunt-non-interactive
        ;;
    "init")
        terragrunt run-all init --terragrunt-working-dir "$ENV_DIR" --terragrunt-non-interactive
        ;;
    *)
        echo -e "${RED}❌ Unknown action: $ACTION${NC}"
        echo -e "${YELLOW}Available actions: plan, apply, destroy, output, init${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}🎉 Root orchestration completed successfully!${NC}"
echo -e "${BLUE}Environment: $ENVIRONMENT${NC}"
echo -e "${BLUE}Action: $ACTION${NC}"