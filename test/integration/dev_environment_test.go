package integration

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-nextjs-infrastructure/test/helpers"
)

func TestDevEnvironmentDeployment(t *testing.T) {
	// This test takes longer due to multiple resources
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	// Setup test configuration
	testConfig := helpers.NewTestConfig(t)
	
	// Define test variables for dev environment
	vars := map[string]interface{}{
		"environment":    "dev-test-" + testConfig.UniqueID,
		"aws_region":     testConfig.Region,
		"domain_name":    "dev-test-" + testConfig.UniqueID + ".example.com",
		"project_name":   "nextjs-infra-test",
		"enable_versioning": false, // Cost optimization for dev
		"mfa_configuration": "OFF", // Simplified for dev
		"price_class":    "PriceClass_100", // Cost optimization
	}

	// Test S3 Website module first
	t.Run("DeployS3Website", func(t *testing.T) {
		websiteVars := map[string]interface{}{
			"bucket_name":       fmt.Sprintf("%s-website-%s", vars["project_name"], testConfig.UniqueID),
			"environment":       vars["environment"],
			"enable_versioning": vars["enable_versioning"],
		}
		
		websiteOptions := testConfig.GetTerraformOptions("../../modules/s3-website", websiteVars)
		helpers.CleanupTerraform(t, websiteOptions, testConfig.Cleanup)
		
		terraform.InitAndApply(t, websiteOptions)
		
		bucketName := terraform.Output(t, websiteOptions, "bucket_name")
		assert.NotEmpty(t, bucketName)
		
		// Store for use in other tests
		vars["website_bucket_name"] = bucketName
		vars["website_bucket_domain"] = terraform.Output(t, websiteOptions, "bucket_domain_name")
	})

	// Test S3 Content module
	t.Run("DeployS3Content", func(t *testing.T) {
		contentVars := map[string]interface{}{
			"bucket_name":       fmt.Sprintf("%s-content-%s", vars["project_name"], testConfig.UniqueID),
			"environment":       vars["environment"],
			"enable_versioning": true, // Always enable for content
		}
		
		contentOptions := testConfig.GetTerraformOptions("../../modules/s3-content", contentVars)
		helpers.CleanupTerraform(t, contentOptions, testConfig.Cleanup)
		
		terraform.InitAndApply(t, contentOptions)
		
		bucketName := terraform.Output(t, contentOptions, "bucket_name")
		assert.NotEmpty(t, bucketName)
		
		vars["content_bucket_name"] = bucketName
	})

	// Test Cognito module
	t.Run("DeployCognito", func(t *testing.T) {
		cognitoVars := map[string]interface{}{
			"user_pool_name": fmt.Sprintf("%s-users-%s", vars["project_name"], testConfig.UniqueID),
			"environment":    vars["environment"],
			"domain_name":    vars["domain_name"],
			"callback_urls":  []string{fmt.Sprintf("https://%s/callback", vars["domain_name"])},
			"logout_urls":    []string{fmt.Sprintf("https://%s/logout", vars["domain_name"])},
			"mfa_configuration": vars["mfa_configuration"],
		}
		
		cognitoOptions := testConfig.GetTerraformOptions("../../modules/cognito", cognitoVars)
		helpers.CleanupTerraform(t, cognitoOptions, testConfig.Cleanup)
		
		terraform.InitAndApply(t, cognitoOptions)
		
		userPoolId := terraform.Output(t, cognitoOptions, "user_pool_id")
		clientId := terraform.Output(t, cognitoOptions, "user_pool_client_id")
		
		assert.NotEmpty(t, userPoolId)
		assert.NotEmpty(t, clientId)
		
		vars["user_pool_id"] = userPoolId
		vars["user_pool_client_id"] = clientId
	})

	// Test CloudFront module (depends on S3 website)
	t.Run("DeployCloudFront", func(t *testing.T) {
		require.Contains(t, vars, "website_bucket_domain", "Website bucket must be deployed first")
		
		cloudfrontVars := map[string]interface{}{
			"distribution_comment": fmt.Sprintf("%s CloudFront Distribution", vars["project_name"]),
			"environment":          vars["environment"],
			"s3_bucket_domain":     vars["website_bucket_domain"],
			"price_class":          vars["price_class"],
			"enable_ipv6":          true,
		}
		
		cloudfrontOptions := testConfig.GetTerraformOptions("../../modules/cloudfront", cloudfrontVars)
		helpers.CleanupTerraform(t, cloudfrontOptions, testConfig.Cleanup)
		
		terraform.InitAndApply(t, cloudfrontOptions)
		
		distributionId := terraform.Output(t, cloudfrontOptions, "distribution_id")
		distributionDomain := terraform.Output(t, cloudfrontOptions, "distribution_domain_name")
		
		assert.NotEmpty(t, distributionId)
		assert.NotEmpty(t, distributionDomain)
		assert.Contains(t, distributionDomain, "cloudfront.net")
		
		vars["distribution_id"] = distributionId
		vars["distribution_domain"] = distributionDomain
	})

	// Validate cross-module integration
	t.Run("ValidateIntegration", func(t *testing.T) {
		// Validate that all components were created
		require.Contains(t, vars, "website_bucket_name")
		require.Contains(t, vars, "content_bucket_name")
		require.Contains(t, vars, "user_pool_id")
		require.Contains(t, vars, "distribution_id")
		
		// Validate naming consistency
		environment := vars["environment"].(string)
		assert.Contains(t, vars["website_bucket_name"], environment)
		assert.Contains(t, vars["content_bucket_name"], environment)
		
		// Validate resource isolation (different bucket names)
		assert.NotEqual(t, vars["website_bucket_name"], vars["content_bucket_name"])
	})
}

func TestDevEnvironmentCostOptimization(t *testing.T) {
	// This test validates cost optimization settings for dev environment
	if testing.Short() {
		t.Skip("Skipping cost optimization test in short mode")
	}

	testConfig := helpers.NewTestConfig(t)
	
	// Test cost-optimized S3 configuration
	t.Run("ValidateCostOptimizedS3", func(t *testing.T) {
		vars := map[string]interface{}{
			"bucket_name":       helpers.GenerateTestResourceName("cost-opt", testConfig.UniqueID),
			"environment":       "dev",
			"enable_versioning": false, // Cost optimization
			"lifecycle_rules": []map[string]interface{}{
				{
					"id":     "cost_optimization",
					"status": "Enabled",
					"transition": []map[string]interface{}{
						{
							"days":          30,
							"storage_class": "STANDARD_IA",
						},
						{
							"days":          90,
							"storage_class": "GLACIER",
						},
					},
				},
			},
		}
		
		options := testConfig.GetTerraformOptions("../../modules/s3-content", vars)
		helpers.CleanupTerraform(t, options, testConfig.Cleanup)
		
		terraform.InitAndApply(t, options)
		
		bucketName := terraform.Output(t, options, "bucket_name")
		assert.NotEmpty(t, bucketName)
		
		// Validate versioning is disabled for cost optimization
		helpers.ValidateS3BucketVersioning(t, testConfig.Region, bucketName, "Disabled")
	})

	// Test cost-optimized CloudFront configuration
	t.Run("ValidateCostOptimizedCloudFront", func(t *testing.T) {
		vars := map[string]interface{}{
			"distribution_comment": "Cost Optimized Distribution",
			"environment":          "dev",
			"s3_bucket_domain":     "test-bucket.s3.amazonaws.com",
			"price_class":          "PriceClass_100", // Cost optimization
			"enable_ipv6":          false, // Simplified for dev
		}
		
		options := testConfig.GetTerraformOptions("../../modules/cloudfront", vars)
		helpers.CleanupTerraform(t, options, testConfig.Cleanup)
		
		terraform.InitAndApply(t, options)
		
		distributionId := terraform.Output(t, options, "distribution_id")
		assert.NotEmpty(t, distributionId)
		
		// Additional validation could be added here to check price class
	})
}

func TestDevEnvironmentRollback(t *testing.T) {
	// Test rollback capabilities
	if testing.Short() {
		t.Skip("Skipping rollback test in short mode")
	}

	testConfig := helpers.NewTestConfig(t)
	
	// Deploy initial configuration
	vars := map[string]interface{}{
		"bucket_name": helpers.GenerateTestResourceName("rollback", testConfig.UniqueID),
		"environment": "dev",
		"enable_versioning": false,
	}
	
	options := testConfig.GetTerraformOptions("../../modules/s3-website", vars)
	
	// Initial deployment
	terraform.InitAndApply(t, options)
	
	initialBucketName := terraform.Output(t, options, "bucket_name")
	assert.NotEmpty(t, initialBucketName)
	
	// Modify configuration
	vars["enable_versioning"] = true
	options.Vars = vars
	
	// Apply changes
	terraform.Apply(t, options)
	
	// Validate changes were applied
	helpers.ValidateS3BucketVersioning(t, testConfig.Region, initialBucketName, "Enabled")
	
	// Rollback changes
	vars["enable_versioning"] = false
	options.Vars = vars
	
	terraform.Apply(t, options)
	
	// Validate rollback was successful
	helpers.ValidateS3BucketVersioning(t, testConfig.Region, initialBucketName, "Suspended")
	
	// Cleanup
	if testConfig.Cleanup {
		terraform.Destroy(t, options)
	}
}