# Production Environment - Provider Configuration
# This file configures the AWS provider and version constraints

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
  region = var.aws_region
  
  default_tags {
    tags = {
      CreatedBy         = "terraform"
      Environment       = var.environment
      ManagedBy         = "terraform"
      Project           = var.project_name
      CostCenter        = var.cost_center
      Owner             = var.owner
      AutoShutdown      = var.auto_shutdown
      Compliance        = var.compliance
      DataClassification = var.data_classification
      BackupRequired    = var.backup_required
      MonitoringLevel   = var.monitoring_level
    }
  }
}

# Additional provider for ACM certificates (must be in us-east-1 for CloudFront)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  
  default_tags {
    tags = {
      CreatedBy         = "terraform"
      Environment       = var.environment
      ManagedBy         = "terraform"
      Project           = var.project_name
      CostCenter        = var.cost_center
      Owner             = var.owner
      AutoShutdown      = var.auto_shutdown
      Compliance        = var.compliance
      DataClassification = var.data_classification
      BackupRequired    = var.backup_required
      MonitoringLevel   = var.monitoring_level
    }
  }
}