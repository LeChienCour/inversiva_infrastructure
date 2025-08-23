# Requirements Document

## Introduction

This feature involves restructuring the existing Terragrunt-based infrastructure project to use pure Terraform with environment-specific configuration files (prod.env and dev.env). The goal is to simplify the project structure, eliminate Terragrunt complexity, and make environment differences more explicit and manageable through environment variable files.

## Requirements

### Requirement 1

**User Story:** As a developer, I want to use pure Terraform instead of Terragrunt, so that I can have a simpler infrastructure setup without the additional complexity layer.

#### Acceptance Criteria

1. WHEN the project is restructured THEN the system SHALL use only Terraform without Terragrunt dependencies
2. WHEN deploying infrastructure THEN the system SHALL NOT require Terragrunt commands or configuration files
3. WHEN managing environments THEN the system SHALL use standard Terraform workspaces or directory structures

### Requirement 2

**User Story:** As a developer, I want environment-specific configuration through .env files, so that I can easily see and manage differences between dev and prod environments.

#### Acceptance Criteria

1. WHEN configuring environments THEN the system SHALL use prod.env and dev.env files to define environment-specific variables
2. WHEN switching environments THEN the system SHALL load the appropriate .env file automatically
3. WHEN adding new environment variables THEN the system SHALL support them in both environment files
4. WHEN deploying THEN the system SHALL validate that required environment variables are present

### Requirement 3

**User Story:** As a developer, I want a simplified project structure, so that I can easily understand and navigate the infrastructure code.

#### Acceptance Criteria

1. WHEN viewing the project THEN the system SHALL have a clear, flat directory structure without nested Terragrunt configurations
2. WHEN organizing modules THEN the system SHALL maintain reusable Terraform modules in a dedicated modules directory
3. WHEN managing environments THEN the system SHALL use a simple approach that doesn't require complex configuration hierarchies
4. WHEN documenting the structure THEN the system SHALL provide clear guidance on file organization

### Requirement 4

**User Story:** As a developer, I want to preserve all existing AWS infrastructure functionality, so that the restructuring doesn't break any current capabilities.

#### Acceptance Criteria

1. WHEN restructuring THEN the system SHALL maintain all existing AWS services (S3, CloudFront, Cognito, Route53, ACM, DynamoDB, CloudWatch)
2. WHEN deploying THEN the system SHALL create the same AWS resources as the current Terragrunt setup
3. WHEN managing state THEN the system SHALL preserve Terraform state management capabilities
4. WHEN running deployments THEN the system SHALL support both dev and prod environments with their specific configurations

### Requirement 5

**User Story:** As a developer, I want simple deployment commands, so that I can deploy infrastructure without complex Terragrunt syntax.

#### Acceptance Criteria

1. WHEN deploying THEN the system SHALL use standard Terraform commands (init, plan, apply)
2. WHEN switching environments THEN the system SHALL use simple environment selection mechanisms
3. WHEN running deployments THEN the system SHALL provide clear, documented command patterns
4. WHEN automating deployments THEN the system SHALL support CI/CD integration with standard Terraform workflows

### Requirement 6

**User Story:** As a developer, I want to maintain security and best practices, so that the simplified structure doesn't compromise infrastructure security.

#### Acceptance Criteria

1. WHEN restructuring THEN the system SHALL maintain all current security configurations
2. WHEN managing secrets THEN the system SHALL handle sensitive variables securely in .env files
3. WHEN deploying THEN the system SHALL continue to support security scanning with Checkov
4. WHEN configuring resources THEN the system SHALL maintain IAM least privilege principles