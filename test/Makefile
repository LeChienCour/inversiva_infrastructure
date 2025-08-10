# Terraform Next.js Infrastructure Testing Makefile

# Variables
GO_VERSION := 1.21
TEST_TIMEOUT := 30m
AWS_REGION ?= us-east-1
TEST_ENVIRONMENT ?= test
CLEANUP_RESOURCES ?= true

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

.PHONY: help test test-modules test-integration test-smoke test-security test-cost test-all clean deps fmt lint

help: ## Show this help message
	@echo "$(BLUE)Terraform Next.js Infrastructure Testing$(NC)"
	@echo ""
	@echo "$(YELLOW)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

deps: ## Install Go dependencies
	@echo "$(BLUE)Installing Go dependencies...$(NC)"
	go mod download
	go mod tidy

fmt: ## Format Go code
	@echo "$(BLUE)Formatting Go code...$(NC)"
	go fmt ./...

lint: ## Lint Go code
	@echo "$(BLUE)Linting Go code...$(NC)"
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run ./...; \
	else \
		echo "$(YELLOW)golangci-lint not found, skipping linting$(NC)"; \
	fi

test-modules: deps ## Run module unit tests
	@echo "$(BLUE)Running module unit tests...$(NC)"
	@export AWS_REGION=$(AWS_REGION) && \
	export TEST_ENVIRONMENT=$(TEST_ENVIRONMENT) && \
	export CLEANUP_RESOURCES=$(CLEANUP_RESOURCES) && \
	go test -v -timeout $(TEST_TIMEOUT) ./modules/...

test-integration: deps ## Run integration tests
	@echo "$(BLUE)Running integration tests...$(NC)"
	@export AWS_REGION=$(AWS_REGION) && \
	export TEST_ENVIRONMENT=$(TEST_ENVIRONMENT) && \
	export CLEANUP_RESOURCES=$(CLEANUP_RESOURCES) && \
	go test -v -timeout $(TEST_TIMEOUT) ./integration/...

test-final-integration: deps ## Run final integration test suite
	@echo "$(BLUE)Running final integration test suite...$(NC)"
	@export AWS_REGION=$(AWS_REGION) && \
	export TEST_ENVIRONMENT=$(TEST_ENVIRONMENT) && \
	export CLEANUP_RESOURCES=$(CLEANUP_RESOURCES) && \
	go test -v -timeout 60m -run TestFinalIntegrationSuite ./integration/

test-e2e: deps ## Run end-to-end infrastructure deployment tests
	@echo "$(BLUE)Running end-to-end deployment tests...$(NC)"
	@export AWS_REGION=$(AWS_REGION) && \
	export TEST_ENVIRONMENT=$(TEST_ENVIRONMENT) && \
	export CLEANUP_RESOURCES=$(CLEANUP_RESOURCES) && \
	go test -v -timeout 45m -run TestCompleteInfrastructureDeployment ./integration/

test-github-actions: deps ## Run GitHub Actions workflow validation tests
	@echo "$(BLUE)Running GitHub Actions workflow tests...$(NC)"
	@export AWS_REGION=$(AWS_REGION) && \
	export TEST_ENVIRONMENT=$(TEST_ENVIRONMENT) && \
	export CLEANUP_RESOURCES=$(CLEANUP_RESOURCES) && \
	go test -v -timeout 10m -run TestGitHubActionsWorkflows ./integration/

test-security-penetration: deps ## Run security penetration tests
	@echo "$(BLUE)Running security penetration tests...$(NC)"
	@export AWS_REGION=$(AWS_REGION) && \
	export TEST_ENVIRONMENT=$(TEST_ENVIRONMENT) && \
	export CLEANUP_RESOURCES=$(CLEANUP_RESOURCES) && \
	go test -v -timeout 30m -run TestSecurityPenetrationTesting ./integration/

test-cross-environment: deps ## Run cross-environment isolation tests
	@echo "$(BLUE)Running cross-environment isolation tests...$(NC)"
	@export AWS_REGION=$(AWS_REGION) && \
	export TEST_ENVIRONMENT=$(TEST_ENVIRONMENT) && \
	export CLEANUP_RESOURCES=$(CLEANUP_RESOURCES) && \
	go test -v -timeout 30m -run TestCrossEnvironmentIsolation ./integration/

test-readiness: deps ## Run infrastructure readiness validation
	@echo "$(BLUE)Running infrastructure readiness tests...$(NC)"
	@export AWS_REGION=$(AWS_REGION) && \
	export TEST_ENVIRONMENT=$(TEST_ENVIRONMENT) && \
	export CLEANUP_RESOURCES=$(CLEANUP_RESOURCES) && \
	go test -v -timeout 10m -run TestInfrastructureReadiness ./integration/

test-smoke: deps ## Run smoke tests
	@echo "$(BLUE)Running smoke tests...$(NC)"
	@export AWS_REGION=$(AWS_REGION) && \
	export TEST_ENVIRONMENT=$(TEST_ENVIRONMENT) && \
	export CLEANUP_RESOURCES=$(CLEANUP_RESOURCES) && \
	go test -v -timeout $(TEST_TIMEOUT) ./smoke/...

test-security: deps ## Run security tests
	@echo "$(BLUE)Running security tests...$(NC)"
	@export AWS_REGION=$(AWS_REGION) && \
	export TEST_ENVIRONMENT=$(TEST_ENVIRONMENT) && \
	export CLEANUP_RESOURCES=$(CLEANUP_RESOURCES) && \
	go test -v -timeout $(TEST_TIMEOUT) ./security/...

test-cost: deps ## Run cost optimization tests
	@echo "$(BLUE)Running cost optimization tests...$(NC)"
	@export AWS_REGION=$(AWS_REGION) && \
	export TEST_ENVIRONMENT=$(TEST_ENVIRONMENT) && \
	export CLEANUP_RESOURCES=$(CLEANUP_RESOURCES) && \
	go test -v -timeout $(TEST_TIMEOUT) ./cost/...

test-all: deps ## Run all tests
	@echo "$(BLUE)Running all tests...$(NC)"
	@export AWS_REGION=$(AWS_REGION) && \
	export TEST_ENVIRONMENT=$(TEST_ENVIRONMENT) && \
	export CLEANUP_RESOURCES=$(CLEANUP_RESOURCES) && \
	go test -v -timeout $(TEST_TIMEOUT) ./...

test-short: deps ## Run tests in short mode (skips long-running tests)
	@echo "$(BLUE)Running tests in short mode...$(NC)"
	@export AWS_REGION=$(AWS_REGION) && \
	export TEST_ENVIRONMENT=$(TEST_ENVIRONMENT) && \
	export CLEANUP_RESOURCES=$(CLEANUP_RESOURCES) && \
	go test -v -short -timeout 10m ./...

test-parallel: deps ## Run tests with increased parallelism
	@echo "$(BLUE)Running tests with increased parallelism...$(NC)"
	@export AWS_REGION=$(AWS_REGION) && \
	export TEST_ENVIRONMENT=$(TEST_ENVIRONMENT) && \
	export CLEANUP_RESOURCES=$(CLEANUP_RESOURCES) && \
	go test -v -timeout $(TEST_TIMEOUT) -parallel 4 ./...

test-specific: deps ## Run specific test (usage: make test-specific TEST=TestS3WebsiteModule)
	@if [ -z "$(TEST)" ]; then \
		echo "$(RED)Error: TEST variable is required$(NC)"; \
		echo "$(YELLOW)Usage: make test-specific TEST=TestS3WebsiteModule$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Running specific test: $(TEST)$(NC)"
	@export AWS_REGION=$(AWS_REGION) && \
	export TEST_ENVIRONMENT=$(TEST_ENVIRONMENT) && \
	export CLEANUP_RESOURCES=$(CLEANUP_RESOURCES) && \
	go test -v -timeout $(TEST_TIMEOUT) -run $(TEST) ./...

clean: ## Clean test artifacts and temporary files
	@echo "$(BLUE)Cleaning test artifacts...$(NC)"
	go clean -testcache
	find . -name "*.tfstate*" -delete
	find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name ".terraform.lock.hcl" -delete

validate-aws: ## Validate AWS credentials and permissions
	@echo "$(BLUE)Validating AWS credentials...$(NC)"
	@aws sts get-caller-identity > /dev/null && \
	echo "$(GREEN)AWS credentials are valid$(NC)" || \
	(echo "$(RED)AWS credentials are not configured or invalid$(NC)" && exit 1)

check-deps: ## Check if required dependencies are installed
	@echo "$(BLUE)Checking dependencies...$(NC)"
	@command -v go >/dev/null 2>&1 || (echo "$(RED)Go is not installed$(NC)" && exit 1)
	@command -v terraform >/dev/null 2>&1 || (echo "$(RED)Terraform is not installed$(NC)" && exit 1)
	@command -v terragrunt >/dev/null 2>&1 || (echo "$(RED)Terragrunt is not installed$(NC)" && exit 1)
	@command -v aws >/dev/null 2>&1 || (echo "$(RED)AWS CLI is not installed$(NC)" && exit 1)
	@echo "$(GREEN)All dependencies are installed$(NC)"

setup: check-deps validate-aws deps ## Setup testing environment
	@echo "$(GREEN)Testing environment is ready!$(NC)"

# CI/CD targets
ci-test: setup test-short ## Run tests suitable for CI/CD

ci-test-full: setup test-all ## Run full test suite for CI/CD

# Development targets
dev-test: ## Run tests with cleanup disabled for development
	@$(MAKE) test-modules CLEANUP_RESOURCES=false

dev-test-integration: ## Run integration tests with cleanup disabled
	@$(MAKE) test-integration CLEANUP_RESOURCES=false

# Report generation
test-report: deps ## Generate test report
	@echo "$(BLUE)Generating test report...$(NC)"
	@export AWS_REGION=$(AWS_REGION) && \
	export TEST_ENVIRONMENT=$(TEST_ENVIRONMENT) && \
	export CLEANUP_RESOURCES=$(CLEANUP_RESOURCES) && \
	go test -v -timeout $(TEST_TIMEOUT) -json ./... > test-report.json
	@echo "$(GREEN)Test report generated: test-report.json$(NC)"

# Coverage targets
test-coverage: deps ## Run tests with coverage
	@echo "$(BLUE)Running tests with coverage...$(NC)"
	@export AWS_REGION=$(AWS_REGION) && \
	export TEST_ENVIRONMENT=$(TEST_ENVIRONMENT) && \
	export CLEANUP_RESOURCES=$(CLEANUP_RESOURCES) && \
	go test -v -timeout $(TEST_TIMEOUT) -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "$(GREEN)Coverage report generated: coverage.html$(NC)"

# Environment-specific targets
test-dev: ## Run tests against dev environment
	@$(MAKE) test-all TEST_ENVIRONMENT=dev

test-prod: ## Run tests against prod environment (use with caution)
	@$(MAKE) test-all TEST_ENVIRONMENT=prod

# Quick validation targets
quick-test: deps ## Run quick validation tests
	@echo "$(BLUE)Running quick validation tests...$(NC)"
	@export AWS_REGION=$(AWS_REGION) && \
	export TEST_ENVIRONMENT=$(TEST_ENVIRONMENT) && \
	export CLEANUP_RESOURCES=$(CLEANUP_RESOURCES) && \
	go test -v -short -timeout 5m ./modules/...

# Help with common issues
troubleshoot: ## Show troubleshooting information
	@echo "$(YELLOW)Common troubleshooting steps:$(NC)"
	@echo ""
	@echo "$(BLUE)1. AWS Credentials:$(NC)"
	@echo "   - Ensure AWS credentials are configured: aws configure"
	@echo "   - Check credentials: aws sts get-caller-identity"
	@echo ""
	@echo "$(BLUE)2. Permissions:$(NC)"
	@echo "   - Ensure your AWS user/role has permissions for:"
	@echo "     * S3 (create/delete buckets, objects)"
	@echo "     * CloudFront (create/delete distributions)"
	@echo "     * Cognito (create/delete user pools)"
	@echo "     * Route53 (create/delete hosted zones)"
	@echo "     * ACM (create/delete certificates)"
	@echo ""
	@echo "$(BLUE)3. Test Failures:$(NC)"
	@echo "   - Run with CLEANUP_RESOURCES=false to inspect resources"
	@echo "   - Check AWS console for resource states"
	@echo "   - Increase timeout for slow tests"
	@echo ""
	@echo "$(BLUE)4. Dependencies:$(NC)"
	@echo "   - Run 'make check-deps' to verify installations"
	@echo "   - Update Go modules: go mod tidy"