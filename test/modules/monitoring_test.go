package test

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go/service/budgets"
	"github.com/aws/aws-sdk-go/service/cloudtrail"
	"github.com/aws/aws-sdk-go/service/cloudwatch"
	"github.com/aws/aws-sdk-go/service/cloudwatchlogs"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestMonitoringModule(t *testing.T) {
	t.Parallel()

	// Pick a random AWS region to test in
	awsRegion := aws.GetRandomStableRegion(t, nil, nil)
	
	// Generate unique names for resources
	uniqueID := random.UniqueId()
	projectName := fmt.Sprintf("test-monitoring-%s", strings.ToLower(uniqueID))
	environment := "test"

	// Create mock S3 buckets and CloudFront distribution for testing
	websiteBucketName := fmt.Sprintf("%s-website-%s", projectName, strings.ToLower(uniqueID))
	contentBucketName := fmt.Sprintf("%s-content-%s", projectName, strings.ToLower(uniqueID))

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../modules/monitoring/examples/basic-example.tf",
		Vars: map[string]interface{}{
			"project_name":               projectName,
			"environment":               environment,
			"alert_email_addresses":     []string{"test@example.com"},
			"monthly_budget_limit":      "25",
			"enable_cloudtrail":        false,
			"log_retention_days":       7,
			"enable_detailed_monitoring": false,
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	})

	// Clean up resources with "terraform destroy" at the end of the test
	defer terraform.Destroy(t, terraformOptions)

	// Run "terraform init" and "terraform apply"
	terraform.InitAndApply(t, terraformOptions)

	// Validate the monitoring infrastructure
	validateMonitoringInfrastructure(t, terraformOptions, awsRegion, projectName, environment)
}

func TestMonitoringModuleProduction(t *testing.T) {
	t.Parallel()

	// Pick a random AWS region to test in
	awsRegion := aws.GetRandomStableRegion(t, nil, nil)
	
	// Generate unique names for resources
	uniqueID := random.UniqueId()
	projectName := fmt.Sprintf("test-monitoring-prod-%s", strings.ToLower(uniqueID))
	environment := "prod"

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../modules/monitoring/examples/production-example.tf",
		Vars: map[string]interface{}{
			"project_name":               projectName,
			"environment":               environment,
			"alert_email_addresses":     []string{"ops@example.com", "admin@example.com"},
			"monthly_budget_limit":      "500",
			"enable_cloudtrail":        true,
			"log_retention_days":       90,
			"enable_detailed_monitoring": true,
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	})

	// Clean up resources with "terraform destroy" at the end of the test
	defer terraform.Destroy(t, terraformOptions)

	// Run "terraform init" and "terraform apply"
	terraform.InitAndApply(t, terraformOptions)

	// Validate the production monitoring infrastructure
	validateProductionMonitoringInfrastructure(t, terraformOptions, awsRegion, projectName, environment)
}

func validateMonitoringInfrastructure(t *testing.T, terraformOptions *terraform.Options, awsRegion, projectName, environment string) {
	// Get outputs from Terraform
	snsTopicArn := terraform.Output(t, terraformOptions, "sns_topic_arn")
	dashboardUrl := terraform.Output(t, terraformOptions, "dashboard_url")

	// Validate SNS Topic
	require.NotEmpty(t, snsTopicArn, "SNS topic ARN should not be empty")
	assert.Contains(t, snsTopicArn, fmt.Sprintf("%s-%s-alerts", projectName, environment))

	// Validate Dashboard URL
	require.NotEmpty(t, dashboardUrl, "Dashboard URL should not be empty")
	assert.Contains(t, dashboardUrl, awsRegion)
	assert.Contains(t, dashboardUrl, "cloudwatch")

	// Validate SNS Topic exists
	snsClient := aws.NewSnsClient(t, awsRegion)
	topics, err := snsClient.ListTopics(nil)
	require.NoError(t, err)

	topicExists := false
	for _, topic := range topics.Topics {
		if *topic.TopicArn == snsTopicArn {
			topicExists = true
			break
		}
	}
	assert.True(t, topicExists, "SNS topic should exist")

	// Validate CloudWatch Dashboard exists
	cloudwatchClient := aws.NewCloudWatchClient(t, awsRegion)
	dashboards, err := cloudwatchClient.ListDashboards(nil)
	require.NoError(t, err)

	expectedDashboardName := fmt.Sprintf("%s-%s-infrastructure", projectName, environment)
	dashboardExists := false
	for _, dashboard := range dashboards.DashboardEntries {
		if *dashboard.DashboardName == expectedDashboardName {
			dashboardExists = true
			break
		}
	}
	assert.True(t, dashboardExists, "CloudWatch dashboard should exist")

	// Validate Budget exists
	budgetClient := aws.NewBudgetsClient(t, awsRegion)
	accountId := aws.GetAccountId(t)
	budgetName := fmt.Sprintf("%s-%s-budget", projectName, environment)
	
	_, err = budgetClient.DescribeBudget(&budgets.DescribeBudgetInput{
		AccountId:  &accountId,
		BudgetName: &budgetName,
	})
	assert.NoError(t, err, "Budget should exist")

	// Validate CloudWatch Alarms exist
	alarms, err := cloudwatchClient.DescribeAlarms(nil)
	require.NoError(t, err)

	alarmPrefix := fmt.Sprintf("%s-%s", projectName, environment)
	alarmCount := 0
	for _, alarm := range alarms.MetricAlarms {
		if strings.HasPrefix(*alarm.AlarmName, alarmPrefix) {
			alarmCount++
		}
	}
	assert.Greater(t, alarmCount, 0, "Should have at least one CloudWatch alarm")
}

func validateProductionMonitoringInfrastructure(t *testing.T, terraformOptions *terraform.Options, awsRegion, projectName, environment string) {
	// Run basic validation first
	validateMonitoringInfrastructure(t, terraformOptions, awsRegion, projectName, environment)

	// Additional production-specific validations
	cloudtrailArn := terraform.Output(t, terraformOptions, "cloudtrail_arn")
	budgetName := terraform.Output(t, terraformOptions, "budget_name")
	alarmNames := terraform.OutputList(t, terraformOptions, "alarm_names")

	// Validate CloudTrail exists (production only)
	require.NotEmpty(t, cloudtrailArn, "CloudTrail ARN should not be empty for production")
	assert.Contains(t, cloudtrailArn, fmt.Sprintf("%s-%s-security-trail", projectName, environment))

	// Validate CloudTrail is logging
	cloudtrailClient := aws.NewCloudTrailClient(t, awsRegion)
	trailName := fmt.Sprintf("%s-%s-security-trail", projectName, environment)
	status, err := cloudtrailClient.GetTrailStatus(&cloudtrail.GetTrailStatusInput{
		Name: &trailName,
	})
	require.NoError(t, err)
	assert.True(t, *status.IsLogging, "CloudTrail should be logging")

	// Validate budget name
	require.NotEmpty(t, budgetName, "Budget name should not be empty")
	assert.Equal(t, fmt.Sprintf("%s-%s-budget", projectName, environment), budgetName)

	// Validate alarm count for production
	require.Greater(t, len(alarmNames), 3, "Production should have multiple alarms")

	// Validate CloudWatch Log Group exists
	logsClient := aws.NewCloudWatchLogsClient(t, awsRegion)
	logGroupName := fmt.Sprintf("/aws/cloudtrail/%s-%s", projectName, environment)
	
	_, err = logsClient.DescribeLogGroups(&cloudwatchlogs.DescribeLogGroupsInput{
		LogGroupNamePrefix: &logGroupName,
	})
	assert.NoError(t, err, "CloudTrail log group should exist")

	// Test alarm states (should be OK initially)
	cloudwatchClient := aws.NewCloudWatchClient(t, awsRegion)
	for _, alarmName := range alarmNames {
		alarms, err := cloudwatchClient.DescribeAlarms(&cloudwatch.DescribeAlarmsInput{
			AlarmNames: []*string{&alarmName},
		})
		require.NoError(t, err)
		require.Len(t, alarms.MetricAlarms, 1)
		
		// Allow some time for alarms to initialize
		time.Sleep(10 * time.Second)
		
		// Alarm should be in OK or INSUFFICIENT_DATA state initially
		state := *alarms.MetricAlarms[0].StateValue
		assert.Contains(t, []string{"OK", "INSUFFICIENT_DATA"}, state, 
			fmt.Sprintf("Alarm %s should be in OK or INSUFFICIENT_DATA state, got %s", alarmName, state))
	}
}

func TestMonitoringModuleValidation(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/monitoring",
	}

	// Validate Terraform configuration
	terraform.Init(t, terraformOptions)
	terraform.Validate(t, terraformOptions)
}

func TestMonitoringModuleInputValidation(t *testing.T) {
	t.Parallel()

	awsRegion := aws.GetRandomStableRegion(t, nil, nil)
	uniqueID := random.UniqueId()
	projectName := fmt.Sprintf("test-monitoring-validation-%s", strings.ToLower(uniqueID))

	// Test invalid environment
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../modules/monitoring",
		Vars: map[string]interface{}{
			"project_name":               projectName,
			"environment":               "invalid", // Invalid environment
			"cloudfront_distribution_id": "MOCK123456789",
			"website_bucket_name":       "mock-website-bucket",
			"website_bucket_arn":        "arn:aws:s3:::mock-website-bucket",
			"content_bucket_name":       "mock-content-bucket",
			"content_bucket_arn":        "arn:aws:s3:::mock-content-bucket",
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	})

	// This should fail validation
	_, err := terraform.InitAndPlanE(t, terraformOptions)
	assert.Error(t, err, "Should fail with invalid environment")
	assert.Contains(t, err.Error(), "Environment must be either 'dev' or 'prod'")

	// Test invalid log retention days
	terraformOptions.Vars["environment"] = "dev"
	terraformOptions.Vars["log_retention_days"] = 999 // Invalid retention period

	_, err = terraform.InitAndPlanE(t, terraformOptions)
	assert.Error(t, err, "Should fail with invalid log retention days")
}