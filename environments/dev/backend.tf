# Development Environment - Backend Configuration
# This file configures the Terraform backend for state management

terraform {
  backend "s3" {
    # S3 bucket for storing Terraform state
    bucket = "terraform-nextjs-infrastructure-tfstate-771899848371-us-east-1"
    
    # State file key for this environment
    key = "dev/terraform.tfstate"
    
    # AWS region where the state bucket is located
    region = "us-east-1"
    
    # DynamoDB table for state locking
    dynamodb_table = "terraform-nextjs-infrastructure-tfstate-lock"
    
    # Enable server-side encryption for state file
    encrypt = true
  }
}