package integration

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gopkg.in/yaml.v3"
)

// GitHubWorkflow represents a GitHub Actions workflow
type GitHubWorkflow struct {
	Name string                 `yaml:"name"`
	On   map[string]interface{} `yaml:"on"`
	Env  map[string]string      `yaml:"env"`
	Jobs map[string]Job         `yaml:"jobs"`
}

// Job represents a GitHub Actions job
type Job struct {
	Name        string                 `yaml:"name"`
	RunsOn      string                 `yaml:"runs-on"`
	Needs       interface{}            `yaml:"needs,omitempty"`
	If          string                 `yaml:"if,omitempty"`
	Environment string                 `yaml:"environment,omitempty"`
	Outputs     map[string]string      `yaml:"outputs,omitempty"`
	Steps       []Step                 `yaml:"steps"`
}

// Step represents a GitHub Actions step
type Step struct {
	Name string                 `yaml:"name"`
	Uses string                 `yaml:"uses,omitempty"`
	Run  string                 `yaml:"run,omitempty"`
	With map[string]interface{} `yaml:"with,omitempty"`
	Env  map[string]string      `yaml:"env,omitempty"`
	If   string                 `yaml:"if,omitempty"`
	ID   string                 `yaml:"id,omitempty"`
}

// TestGitHubActionsWorkflows validates GitHub Actions deployment workflows
func TestGitHubActionsWorkflows(t *testing.T) {
	workflowsDir := "../../.github/workflows"
	
	// Test both dev and prod deployment workflows
	workflows := map[string]string{
		"dev":  "deploy-dev.yml",
		"prod": "deploy-prod.yml",
	}
	
	for env, workflowFile := range workflows {
		t.Run(fmt.Sprintf("Validate_%s_Workflow", env), func(t *testing.T) {
			validateDeploymentWorkflow(t, workflowsDir, workflowFile, env)
		})
	}
	
	// Test the test workflow
	t.Run("ValidateTestWorkflow", func(t *testing.T) {
		validateTestWorkflow(t, "../../test/.github/workflows", "test.yml")
	})
}

func validateDeploymentWorkflow(t *testing.T, workflowsDir, workflowFile, environment string) {
	workflowPath := filepath.Join(workflowsDir, workflowFile)
	
	// Check if workflow file exists
	require.FileExists(t, workflowPath, "Workflow file should exist")
	
	// Read and parse workflow
	content, err := ioutil.ReadFile(workflowPath)
	require.NoError(t, err, "Should be able to read workflow file")
	
	var workflow GitHubWorkflow
	err = yaml.Unmarshal(content, &workflow)
	require.NoError(t, err, "Should be able to parse workflow YAML")
	
	// Validate basic workflow structure
	assert.NotEmpty(t, workflow.Name, "Workflow should have a name")
	assert.Contains(t, strings.ToLower(workflow.Name), environment, "Workflow name should contain environment")
	
	// Validate triggers
	require.Contains(t, workflow.On, "push", "Workflow should have push trigger")
	require.Contains(t, workflow.On, "workflow_dispatch", "Workflow should have manual trigger")
	
	// Validate environment variables
	require.Contains(t, workflow.Env, "AWS_REGION", "Workflow should define AWS_REGION")
	require.Contains(t, workflow.Env, "TERRAGRUNT_VERSION", "Workflow should define TERRAGRUNT_VERSION")
	require.Contains(t, workflow.Env, "TERRAFORM_VERSION", "Workflow should define TERRAFORM_VERSION")
	
	// Validate required jobs
	requiredJobs := []string{"validate", "security-scan", "plan"}
	for _, jobName := range requiredJobs {
		require.Contains(t, workflow.Jobs, jobName, fmt.Sprintf("Workflow should have %s job", jobName))
	}
	
	// Validate job dependencies and structure
	validateJobStructure(t, workflow.Jobs, environment)
	
	// Validate security scanning
	validateSecurityScanJob(t, workflow.Jobs["security-scan"], environment)
	
	// Validate deployment jobs
	if environment == "prod" {
		validateProductionSpecificJobs(t, workflow.Jobs)
	} else {
		validateDevelopmentSpecificJobs(t, workflow.Jobs)
	}
}

func validateJobStructure(t *testing.T, jobs map[string]Job, environment string) {
	// Validate job dependencies
	planJob := jobs["plan"]
	assert.Contains(t, fmt.Sprintf("%v", planJob.Needs), "validate", "Plan job should depend on validate")
	assert.Contains(t, fmt.Sprintf("%v", planJob.Needs), "security-scan", "Plan job should depend on security-scan")
	
	// Validate environment protection
	if environment == "prod" {
		assert.Contains(t, planJob.Environment, "production", "Production plan should use production environment")
	} else {
		assert.Contains(t, planJob.Environment, "development", "Development plan should use development environment")
	}
	
	// Validate runner
	for jobName, job := range jobs {
		assert.Equal(t, "ubuntu-latest", job.RunsOn, fmt.Sprintf("Job %s should run on ubuntu-latest", jobName))
	}
}

func validateSecurityScanJob(t *testing.T, job Job, environment string) {
	// Validate security scan steps
	stepNames := make([]string, len(job.Steps))
	for i, step := range job.Steps {
		stepNames[i] = step.Name
	}
	
	// Required security scan steps
	requiredSteps := []string{
		"Checkout code",
		"Install Checkov",
		"Run",
	}
	
	for _, requiredStep := range requiredSteps {
		found := false
		for _, stepName := range stepNames {
			if strings.Contains(stepName, requiredStep) {
				found = true
				break
			}
		}
		assert.True(t, found, fmt.Sprintf("Security scan should have step containing '%s'", requiredStep))
	}
	
	// Validate Checkov configuration
	for _, step := range job.Steps {
		if strings.Contains(step.Run, "checkov") {
			assert.Contains(t, step.Run, "--config-file .checkov.yml", "Checkov should use config file")
			assert.Contains(t, step.Run, "--baseline .checkov.baseline", "Checkov should use baseline")
			
			if environment == "prod" {
				assert.Contains(t, step.Run, "--hard-fail-on", "Production should have hard fail conditions")
			}
		}
	}
}

func validateProductionSpecificJobs(t *testing.T, jobs map[string]Job) {
	// Production should have additional jobs
	requiredProdJobs := []string{"backup-state", "approval", "apply", "rollback"}
	for _, jobName := range requiredProdJobs {
		assert.Contains(t, jobs, jobName, fmt.Sprintf("Production workflow should have %s job", jobName))
	}
	
	// Validate approval job
	if approvalJob, exists := jobs["approval"]; exists {
		assert.Contains(t, approvalJob.Environment, "production-approval", "Approval job should use production-approval environment")
	}
	
	// Validate backup job
	if backupJob, exists := jobs["backup-state"]; exists {
		// Should have steps for backing up state
		found := false
		for _, step := range backupJob.Steps {
			if strings.Contains(step.Name, "Backup") || strings.Contains(step.Run, "backup") {
				found = true
				break
			}
		}
		assert.True(t, found, "Backup job should have backup steps")
	}
}

func validateDevelopmentSpecificJobs(t *testing.T, jobs map[string]Job) {
	// Development should have apply job but not approval
	assert.Contains(t, jobs, "apply", "Development workflow should have apply job")
	assert.NotContains(t, jobs, "approval", "Development workflow should not require approval")
	
	// Apply job should run automatically
	applyJob := jobs["apply"]
	assert.Contains(t, applyJob.If, "push", "Development apply should trigger on push")
}

func validateTestWorkflow(t *testing.T, workflowsDir, workflowFile string) {
	workflowPath := filepath.Join(workflowsDir, workflowFile)
	
	// Check if workflow file exists
	require.FileExists(t, workflowPath, "Test workflow file should exist")
	
	// Read and parse workflow
	content, err := ioutil.ReadFile(workflowPath)
	require.NoError(t, err, "Should be able to read test workflow file")
	
	var workflow GitHubWorkflow
	err = yaml.Unmarshal(content, &workflow)
	require.NoError(t, err, "Should be able to parse test workflow YAML")
	
	// Validate test workflow structure
	assert.Contains(t, workflow.Name, "Test", "Test workflow should have 'Test' in name")
	
	// Validate test jobs
	requiredTestJobs := []string{"validate", "unit-tests", "integration-tests", "smoke-tests", "security-tests"}
	for _, jobName := range requiredTestJobs {
		assert.Contains(t, workflow.Jobs, jobName, fmt.Sprintf("Test workflow should have %s job", jobName))
	}
	
	// Validate test job conditions
	for jobName, job := range workflow.Jobs {
		if strings.Contains(jobName, "tests") && jobName != "unit-tests" {
			// Integration, smoke, and security tests should require AWS credentials
			found := false
			for _, step := range job.Steps {
				if strings.Contains(step.Uses, "aws-actions/configure-aws-credentials") {
					found = true
					break
				}
			}
			assert.True(t, found, fmt.Sprintf("Job %s should configure AWS credentials", jobName))
		}
	}
}

// TestWorkflowSyntax validates that all workflow files have valid YAML syntax
func TestWorkflowSyntax(t *testing.T) {
	workflowDirs := []string{
		"../../.github/workflows",
		"../../test/.github/workflows",
	}
	
	for _, dir := range workflowDirs {
		if _, err := os.Stat(dir); os.IsNotExist(err) {
			continue
		}
		
		files, err := ioutil.ReadDir(dir)
		require.NoError(t, err, fmt.Sprintf("Should be able to read directory %s", dir))
		
		for _, file := range files {
			if strings.HasSuffix(file.Name(), ".yml") || strings.HasSuffix(file.Name(), ".yaml") {
				t.Run(fmt.Sprintf("ValidateSyntax_%s", file.Name()), func(t *testing.T) {
					filePath := filepath.Join(dir, file.Name())
					content, err := ioutil.ReadFile(filePath)
					require.NoError(t, err, "Should be able to read workflow file")
					
					var workflow interface{}
					err = yaml.Unmarshal(content, &workflow)
					assert.NoError(t, err, fmt.Sprintf("Workflow %s should have valid YAML syntax", file.Name()))
				})
			}
		}
	}
}

// TestWorkflowSecrets validates that workflows reference required secrets
func TestWorkflowSecrets(t *testing.T) {
	workflowsDir := "../../.github/workflows"
	
	workflows := []string{"deploy-dev.yml", "deploy-prod.yml"}
	requiredSecrets := []string{
		"AWS_ACCESS_KEY_ID",
		"AWS_SECRET_ACCESS_KEY",
	}
	
	for _, workflowFile := range workflows {
		t.Run(fmt.Sprintf("ValidateSecrets_%s", workflowFile), func(t *testing.T) {
			workflowPath := filepath.Join(workflowsDir, workflowFile)
			
			if _, err := os.Stat(workflowPath); os.IsNotExist(err) {
				t.Skip("Workflow file does not exist")
			}
			
			content, err := ioutil.ReadFile(workflowPath)
			require.NoError(t, err, "Should be able to read workflow file")
			
			contentStr := string(content)
			
			for _, secret := range requiredSecrets {
				assert.Contains(t, contentStr, fmt.Sprintf("secrets.%s", secret),
					fmt.Sprintf("Workflow should reference secret %s", secret))
			}
		})
	}
}

// TestWorkflowEnvironments validates that workflows use proper GitHub environments
func TestWorkflowEnvironments(t *testing.T) {
	workflowsDir := "../../.github/workflows"
	
	expectedEnvironments := map[string][]string{
		"deploy-dev.yml": {
			"development",
		},
		"deploy-prod.yml": {
			"production-plan",
			"production-approval", 
			"production",
			"production-rollback",
		},
	}
	
	for workflowFile, environments := range expectedEnvironments {
		t.Run(fmt.Sprintf("ValidateEnvironments_%s", workflowFile), func(t *testing.T) {
			workflowPath := filepath.Join(workflowsDir, workflowFile)
			
			if _, err := os.Stat(workflowPath); os.IsNotExist(err) {
				t.Skip("Workflow file does not exist")
			}
			
			content, err := ioutil.ReadFile(workflowPath)
			require.NoError(t, err, "Should be able to read workflow file")
			
			var workflow GitHubWorkflow
			err = yaml.Unmarshal(content, &workflow)
			require.NoError(t, err, "Should be able to parse workflow YAML")
			
			// Check that required environments are referenced
			contentStr := string(content)
			for _, env := range environments {
				assert.Contains(t, contentStr, env,
					fmt.Sprintf("Workflow should reference environment %s", env))
			}
		})
	}
}

// TestWorkflowArtifacts validates that workflows properly handle artifacts
func TestWorkflowArtifacts(t *testing.T) {
	workflowsDir := "../../.github/workflows"
	
	workflows := []string{"deploy-dev.yml", "deploy-prod.yml"}
	
	for _, workflowFile := range workflows {
		t.Run(fmt.Sprintf("ValidateArtifacts_%s", workflowFile), func(t *testing.T) {
			workflowPath := filepath.Join(workflowsDir, workflowFile)
			
			if _, err := os.Stat(workflowPath); os.IsNotExist(err) {
				t.Skip("Workflow file does not exist")
			}
			
			content, err := ioutil.ReadFile(workflowPath)
			require.NoError(t, err, "Should be able to read workflow file")
			
			contentStr := string(content)
			
			// Should upload security scan results
			assert.Contains(t, contentStr, "upload-artifact",
				"Workflow should upload artifacts")
			assert.Contains(t, contentStr, "security-scan",
				"Workflow should upload security scan artifacts")
			
			// Production should also upload plan artifacts
			if strings.Contains(workflowFile, "prod") {
				assert.Contains(t, contentStr, "plan-artifacts",
					"Production workflow should upload plan artifacts")
			}
		})
	}
}

// TestWorkflowNotifications validates notification configurations
func TestWorkflowNotifications(t *testing.T) {
	workflowsDir := "../../.github/workflows"
	
	// Production workflow should have notifications
	workflowFile := "deploy-prod.yml"
	workflowPath := filepath.Join(workflowsDir, workflowFile)
	
	if _, err := os.Stat(workflowPath); os.IsNotExist(err) {
		t.Skip("Production workflow file does not exist")
	}
	
	content, err := ioutil.ReadFile(workflowPath)
	require.NoError(t, err, "Should be able to read workflow file")
	
	contentStr := string(content)
	
	// Should have Slack notifications
	assert.Contains(t, contentStr, "SLACK_WEBHOOK_URL",
		"Production workflow should support Slack notifications")
	
	// Should notify on various events
	notificationEvents := []string{"success", "failure", "start"}
	for _, event := range notificationEvents {
		assert.Contains(t, contentStr, fmt.Sprintf("Notify.*%s", event),
			fmt.Sprintf("Production workflow should notify on %s", event))
	}
}