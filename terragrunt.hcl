# Root Terragrunt configuration
# This file contains common configuration shared across all environments

locals {
  # Common variables
  project_name = "terraform-nextjs-infrastructure"
  
  # AWS account and region configuration
  aws_account_id = get_aws_account_id()
  aws_region     = "us-east-1"  # Using us-east-1 for CloudFront and ACM compatibility
  
  # Environment-specific configuration
  environment = basename(dirname(get_terragrunt_dir()))
  
  # Common tags applied to all resources
  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "terragrunt"
    CreatedBy   = "terraform"
  }
  
  # State bucket configuration
  state_bucket_name = "${local.project_name}-tfstate-${local.aws_account_id}-${local.aws_region}"
  dynamodb_table_name = "${local.project_name}-tfstate-lock"
  
  # Provider version constraints
  terraform_version_constraint = ">= 1.0"
  aws_provider_version = "~> 5.0"
  random_provider_version = "~> 3.1"
}

# Configure Terragrunt to automatically store tfstate files in an S3 bucket
remote_state {
  backend = "s3"
  
  config = {
    encrypt        = true
    bucket         = local.state_bucket_name
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    dynamodb_table = local.dynamodb_table_name
    
    # Enable S3 bucket versioning for state file recovery
    s3_bucket_tags = merge(local.common_tags, {
      Name        = local.state_bucket_name
      Purpose     = "terraform-state-storage"
      Encryption  = "AES256"
    })
    
    # DynamoDB table tags
    dynamodb_table_tags = merge(local.common_tags, {
      Name    = local.dynamodb_table_name
      Purpose = "terraform-state-locking"
    })
  }
  
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Configure inputs that are common across all environments
inputs = {
  project_name   = local.project_name
  aws_account_id = local.aws_account_id
  aws_region     = local.aws_region
  common_tags    = local.common_tags
  
  # Provider configuration for child modules
  terraform_version_constraint = local.terraform_version_constraint
  aws_provider_version = local.aws_provider_version
  random_provider_version = local.random_provider_version
}

# Enable running terragrunt commands from root directory
# This allows commands like: terragrunt run-all plan --terragrunt-working-dir environments/dev
terragrunt_version_constraint = ">= 0.45.0"

# Generate provider configuration for all child modules
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = "${local.aws_region}"
  
  default_tags {
    tags = ${jsonencode(local.common_tags)}
  }
}

# Additional provider for ACM certificates (must be in us-east-1 for CloudFront)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  
  default_tags {
    tags = ${jsonencode(local.common_tags)}
  }
}
EOF
}