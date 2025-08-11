package integration

import (
	"encoding/json"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-nextjs-infrastructure/test/helpers"
)

// IntegrationTestSuite represents the complete integration test suite
type IntegrationTestSuite struct {
	Config          *helpers.TestConfig
	TestResults     map[string]TestResult
	StartTime       time.Time
	EndTime         time.Time
	TotalTests      int
	PassedTests     int
	FailedTests     int
	SkippedTests    int
}

// TestResult represents the result of an individual test
type TestResult struct {
	Name        string        `json:"name"`
	Status      string        `json:"status"` // "PASS", "FAIL", "SKIP"
	Duration    time.Duration `json:"duration"`
	Error       string        `json:"error,omitempty"`
	StartTime   time.Time     `json:"start_time"`
	EndTime     time.Time     `json:"end_time"`
	Environment string        `json:"environment,omitempty"`
	Resources   []string      `json:"resources,omitempty"`
}

// TestFinalIntegrationSuite runs the complete final integration test suite
func TestFinalIntegrationSuite(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping final integration test suite in short mode")
	}

	suite := &IntegrationTestSuite{
		Config:      helpers.NewTestConfig(t),
		TestResults: make(map[string]TestResult),
		StartTime:   time.Now(),
	}

	// Run the complete test suite
	t.Run("CompleteInfrastructureDeployment", func(t *testing.T) {
		suite.runTest(t, "CompleteInfrastructureDeployment", func(t *testing.T) {
			TestCompleteInfrastructureDeployment(t)
		})
	})

	t.Run("CrossEnvironmentIsolation", func(t *testing.T) {
		suite.runTest(t, "CrossEnvironmentIsolation", func(t *testing.T) {
			TestCrossEnvironmentIsolation(t)
		})
	})

	t.Run("ResourceSeparation", func(t *testing.T) {
		suite.runTest(t, "ResourceSeparation", func(t *testing.T) {
			TestResourceSeparation(t)
		})
	})

	t.Run("GitHubActionsWorkflows", func(t *testing.T) {
		suite.runTest(t, "GitHubActionsWorkflows", func(t *testing.T) {
			TestGitHubActionsWorkflows(t)
		})
	})

	t.Run("WorkflowSyntax", func(t *testing.T) {
		suite.runTest(t, "WorkflowSyntax", func(t *testing.T) {
			TestWorkflowSyntax(t)
		})
	})

	t.Run("WorkflowSecrets", func(t *testing.T) {
		suite.runTest(t, "WorkflowSecrets", func(t *testing.T) {
			TestWorkflowSecrets(t)
		})
	})

	t.Run("SecurityPenetrationTesting", func(t *testing.T) {
		suite.runTest(t, "SecurityPenetrationTesting", func(t *testing.T) {
			TestSecurityPenetrationTesting(t)
		})
	})

	t.Run("DeploymentRollback", func(t *testing.T) {
		suite.runTest(t, "DeploymentRollback", func(t *testing.T) {
			TestDeploymentRollback(t)
		})
	})

	t.Run("FailureRecovery", func(t *testing.T) {
		suite.runTest(t, "FailureRecovery", func(t *testing.T) {
			TestFailureRecovery(t)
		})
	})

	// Finalize test suite
	suite.EndTime = time.Now()
	suite.generateReport(t)
}

func (suite *IntegrationTestSuite) runTest(t *testing.T, testName string, testFunc func(*testing.T)) {
	startTime := time.Now()
	
	// Create a sub-test to capture results
	success := t.Run(testName, func(subT *testing.T) {
		defer func() {
			if r := recover(); r != nil {
				suite.recordTestResult(testName, "FAIL", startTime, time.Now(), fmt.Sprintf("Panic: %v", r))
				subT.Errorf("Test panicked: %v", r)
			}
		}()
		
		testFunc(subT)
		
		if subT.Failed() {
			suite.recordTestResult(testName, "FAIL", startTime, time.Now(), "Test failed")
		} else if subT.Skipped() {
			suite.recordTestResult(testName, "SKIP", startTime, time.Now(), "Test skipped")
		} else {
			suite.recordTestResult(testName, "PASS", startTime, time.Now(), "")
		}
	})
	
	if !success {
		suite.recordTestResult(testName, "FAIL", startTime, time.Now(), "Test execution failed")
	}
}

func (suite *IntegrationTestSuite) recordTestResult(name, status string, startTime, endTime time.Time, errorMsg string) {
	result := TestResult{
		Name:      name,
		Status:    status,
		Duration:  endTime.Sub(startTime),
		StartTime: startTime,
		EndTime:   endTime,
		Error:     errorMsg,
	}
	
	suite.TestResults[name] = result
	suite.TotalTests++
	
	switch status {
	case "PASS":
		suite.PassedTests++
	case "FAIL":
		suite.FailedTests++
	case "SKIP":
		suite.SkippedTests++
	}
}

func (suite *IntegrationTestSuite) generateReport(t *testing.T) {
	totalDuration := suite.EndTime.Sub(suite.StartTime)
	
	// Generate console report
	fmt.Printf("\n" + "="*80 + "\n")
	fmt.Printf("FINAL INTEGRATION TEST SUITE REPORT\n")
	fmt.Printf("="*80 + "\n")
	fmt.Printf("Total Duration: %v\n", totalDuration)
	fmt.Printf("Total Tests: %d\n", suite.TotalTests)
	fmt.Printf("Passed: %d\n", suite.PassedTests)
	fmt.Printf("Failed: %d\n", suite.FailedTests)
	fmt.Printf("Skipped: %d\n", suite.SkippedTests)
	fmt.Printf("Success Rate: %.2f%%\n", float64(suite.PassedTests)/float64(suite.TotalTests)*100)
	fmt.Printf("\n")
	
	// Print individual test results
	fmt.Printf("Individual Test Results:\n")
	fmt.Printf("-"*80 + "\n")
	for name, result := range suite.TestResults {
		status := result.Status
		statusSymbol := "✓"
		if status == "FAIL" {
			statusSymbol = "✗"
		} else if status == "SKIP" {
			statusSymbol = "⊝"
		}
		
		fmt.Printf("%s %-40s %s (%v)\n", statusSymbol, name, status, result.Duration)
		if result.Error != "" {
			fmt.Printf("    Error: %s\n", result.Error)
		}
	}
	
	// Generate JSON report
	suite.generateJSONReport(t)
	
	// Generate summary for GitHub Actions
	suite.generateGitHubActionsSummary(t)
	
	// Assert overall success
	if suite.FailedTests > 0 {
		t.Errorf("Integration test suite failed: %d out of %d tests failed", suite.FailedTests, suite.TotalTests)
	}
}

func (suite *IntegrationTestSuite) generateJSONReport(t *testing.T) {
	report := map[string]interface{}{
		"suite_name":     "Final Integration Test Suite",
		"start_time":     suite.StartTime,
		"end_time":       suite.EndTime,
		"total_duration": suite.EndTime.Sub(suite.StartTime).String(),
		"total_tests":    suite.TotalTests,
		"passed_tests":   suite.PassedTests,
		"failed_tests":   suite.FailedTests,
		"skipped_tests":  suite.SkippedTests,
		"success_rate":   float64(suite.PassedTests) / float64(suite.TotalTests) * 100,
		"test_results":   suite.TestResults,
		"environment": map[string]string{
			"aws_region":        suite.Config.Region,
			"test_environment":  suite.Config.Environment,
			"unique_id":         suite.Config.UniqueID,
			"cleanup_enabled":   fmt.Sprintf("%t", suite.Config.Cleanup),
		},
	}
	
	jsonData, err := json.MarshalIndent(report, "", "  ")
	if err != nil {
		t.Logf("Failed to generate JSON report: %v", err)
		return
	}
	
	// Write to file
	reportFile := fmt.Sprintf("integration-test-report-%s.json", suite.Config.UniqueID)
	err = os.WriteFile(reportFile, jsonData, 0644)
	if err != nil {
		t.Logf("Failed to write JSON report to file: %v", err)
	} else {
		fmt.Printf("\nJSON report written to: %s\n", reportFile)
	}
}

func (suite *IntegrationTestSuite) generateGitHubActionsSummary(t *testing.T) {
	// Generate GitHub Actions job summary if running in CI
	if os.Getenv("GITHUB_ACTIONS") == "true" {
		summaryFile := os.Getenv("GITHUB_STEP_SUMMARY")
		if summaryFile != "" {
			summary := suite.generateMarkdownSummary()
			err := os.WriteFile(summaryFile, []byte(summary), 0644)
			if err != nil {
				t.Logf("Failed to write GitHub Actions summary: %v", err)
			}
		}
	}
}

func (suite *IntegrationTestSuite) generateMarkdownSummary() string {
	summary := fmt.Sprintf(`# Final Integration Test Suite Results

## Summary
- **Total Duration**: %v
- **Total Tests**: %d
- **Passed**: %d ✅
- **Failed**: %d ❌
- **Skipped**: %d ⊝
- **Success Rate**: %.2f%%

## Test Environment
- **AWS Region**: %s
- **Test Environment**: %s
- **Unique ID**: %s
- **Cleanup Enabled**: %t

## Individual Test Results

| Test Name | Status | Duration | Error |
|-----------|--------|----------|-------|
`,
		suite.EndTime.Sub(suite.StartTime),
		suite.TotalTests,
		suite.PassedTests,
		suite.FailedTests,
		suite.SkippedTests,
		float64(suite.PassedTests)/float64(suite.TotalTests)*100,
		suite.Config.Region,
		suite.Config.Environment,
		suite.Config.UniqueID,
		suite.Config.Cleanup,
	)
	
	for name, result := range suite.TestResults {
		statusEmoji := "✅"
		if result.Status == "FAIL" {
			statusEmoji = "❌"
		} else if result.Status == "SKIP" {
			statusEmoji = "⊝"
		}
		
		errorMsg := result.Error
		if errorMsg == "" {
			errorMsg = "-"
		}
		
		summary += fmt.Sprintf("| %s | %s %s | %v | %s |\n",
			name, statusEmoji, result.Status, result.Duration, errorMsg)
	}
	
	// Add recommendations based on results
	if suite.FailedTests > 0 {
		summary += "\n## ⚠️ Action Required\n\n"
		summary += "Some tests failed. Please review the errors above and:\n"
		summary += "1. Check the detailed test logs\n"
		summary += "2. Verify AWS permissions and resource availability\n"
		summary += "3. Ensure all prerequisites are met\n"
		summary += "4. Re-run failed tests after addressing issues\n"
	} else {
		summary += "\n## ✅ All Tests Passed\n\n"
		summary += "The infrastructure is ready for deployment!\n"
	}
	
	return summary
}

// TestInfrastructureReadiness validates that the infrastructure is ready for production use
func TestInfrastructureReadiness(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping infrastructure readiness test in short mode")
	}

	testConfig := helpers.NewTestConfig(t)
	
	// Check prerequisites
	t.Run("Prerequisites", func(t *testing.T) {
		// Check AWS credentials
		region := os.Getenv("AWS_REGION")
		assert.NotEmpty(t, region, "AWS_REGION environment variable should be set")
		
		// Check required tools
		// This would typically check for terraform, terragrunt, etc.
		// For now, we'll just validate the test configuration
		assert.NotEmpty(t, testConfig.Region, "Test region should be configured")
		assert.NotEmpty(t, testConfig.UniqueID, "Unique ID should be generated")
	})
	
	// Validate module structure
	t.Run("ModuleStructure", func(t *testing.T) {
		requiredModules := []string{
			"../../modules/s3-website",
			"../../modules/s3-content", 
			"../../modules/cognito",
			"../../modules/cloudfront",
			"../../modules/route53-acm",
		}
		
		for _, modulePath := range requiredModules {
			assert.DirExists(t, modulePath, fmt.Sprintf("Module directory %s should exist", modulePath))
			
			// Check for required files
			requiredFiles := []string{"main.tf", "variables.tf", "outputs.tf"}
			for _, file := range requiredFiles {
				filePath := fmt.Sprintf("%s/%s", modulePath, file)
				assert.FileExists(t, filePath, fmt.Sprintf("Module file %s should exist", filePath))
			}
		}
	})
	
	// Validate environment configurations
	t.Run("EnvironmentConfigurations", func(t *testing.T) {
		environments := []string{"dev", "prod"}
		
		for _, env := range environments {
			envPath := fmt.Sprintf("../../environments/%s", env)
			assert.DirExists(t, envPath, fmt.Sprintf("Environment directory %s should exist", env))
			
			// Check for terragrunt configuration
			terragruntFile := fmt.Sprintf("%s/terragrunt.hcl", envPath)
			assert.FileExists(t, terragruntFile, fmt.Sprintf("Terragrunt config for %s should exist", env))
		}
	})
	
	// Validate GitHub Actions workflows
	t.Run("GitHubActionsWorkflows", func(t *testing.T) {
		workflowsDir := "../../.github/workflows"
		requiredWorkflows := []string{"deploy-dev.yml", "deploy-prod.yml"}
		
		for _, workflow := range requiredWorkflows {
			workflowPath := fmt.Sprintf("%s/%s", workflowsDir, workflow)
			assert.FileExists(t, workflowPath, fmt.Sprintf("Workflow %s should exist", workflow))
		}
	})
	
	// Validate documentation
	t.Run("Documentation", func(t *testing.T) {
		requiredDocs := []string{
			"../../README.md",
			"../../docs/ARCHITECTURE.md",
			"../../docs/DEVELOPMENT_DEPLOYMENT.md",
			"../../docs/TROUBLESHOOTING.md",
		}
		
		for _, doc := range requiredDocs {
			assert.FileExists(t, doc, fmt.Sprintf("Documentation file %s should exist", doc))
		}
	})
}

// TestComplianceValidation validates compliance with security and operational requirements
func TestComplianceValidation(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping compliance validation test in short mode")
	}

	// Validate security scanning configuration
	t.Run("SecurityScanning", func(t *testing.T) {
		// Check Checkov configuration
		assert.FileExists(t, "../../.checkov.yml", "Checkov configuration should exist")
		assert.FileExists(t, "../../.checkov.baseline", "Checkov baseline should exist")
		
		// Check custom policies
		customPoliciesDir := "../../.checkov/custom_policies"
		assert.DirExists(t, customPoliciesDir, "Custom Checkov policies directory should exist")
	})
	
	// Validate cost optimization
	t.Run("CostOptimization", func(t *testing.T) {
		// Check cost optimization documentation
		assert.FileExists(t, "../../docs/COST_OPTIMIZATION.md", "Cost optimization documentation should exist")
		assert.FileExists(t, "../../docs/MONITORING_COSTS.md", "Cost monitoring documentation should exist")
		
		// Check cost monitoring scripts
		assert.FileExists(t, "../../scripts/cost-monitor.sh", "Cost monitoring script should exist")
		assert.FileExists(t, "../../scripts/cost-monitor.ps1", "Cost monitoring PowerShell script should exist")
	})
	
	// Validate monitoring and alerting
	t.Run("MonitoringAlerting", func(t *testing.T) {
		// Check monitoring module
		assert.DirExists(t, "../../modules/monitoring", "Monitoring module should exist")
		
		// Check monitoring documentation
		assert.FileExists(t, "../../docs/MONITORING.md", "Monitoring documentation should exist")
		
		// Check monitoring scripts
		assert.FileExists(t, "../../scripts/monitoring-health.sh", "Monitoring health script should exist")
		assert.FileExists(t, "../../scripts/monitoring-health.ps1", "Monitoring health PowerShell script should exist")
	})
	
	// Validate backup and recovery
	t.Run("BackupRecovery", func(t *testing.T) {
		// Check that production workflow includes backup steps
		prodWorkflow := "../../.github/workflows/deploy-prod.yml"
		if assert.FileExists(t, prodWorkflow, "Production workflow should exist") {
			// Read workflow content and check for backup steps
			// This is a simplified check - in practice you'd parse the YAML
			content, err := os.ReadFile(prodWorkflow)
			require.NoError(t, err)
			
			contentStr := string(content)
			assert.Contains(t, contentStr, "backup", "Production workflow should include backup steps")
			assert.Contains(t, contentStr, "rollback", "Production workflow should include rollback capability")
		}
	})
}