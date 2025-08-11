package modules

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-nextjs-infrastructure/test/helpers"
)

func TestS3WebsiteModule(t *testing.T) {
	t.Parallel()

	// Setup test configuration
	testConfig := helpers.NewTestConfig(t)
	
	// Define test variables
	vars := map[string]interface{}{
		"bucket_name":       helpers.GenerateTestResourceName("website", testConfig.UniqueID),
		"enable_versioning": false,
		"environment":       testConfig.Environment,
		"tags": map[string]string{
			"Environment": testConfig.Environment,
			"Testing":     "true",
		},
	}

	// Configure Terraform options
	terraformOptions := testConfig.GetTerraformOptions("../../modules/s3-website", vars)
	
	// Cleanup resources after test
	helpers.CleanupTerraform(t, terraformOptions, testConfig.Cleanup)

	// Run terraform init and apply
	terraform.InitAndApply(t, terraformOptions)

	// Validate outputs
	bucketName := terraform.Output(t, terraformOptions, "bucket_name")
	bucketArn := terraform.Output(t, terraformOptions, "bucket_arn")
	websiteEndpoint := terraform.Output(t, terraformOptions, "website_endpoint")
	bucketDomainName := terraform.Output(t, terraformOptions, "bucket_domain_name")

	// Assertions
	assert.NotEmpty(t, bucketName)
	assert.NotEmpty(t, bucketArn)
	assert.NotEmpty(t, websiteEndpoint)
	assert.NotEmpty(t, bucketDomainName)
	assert.Contains(t, bucketArn, bucketName)
	assert.Contains(t, websiteEndpoint, bucketName)

	// Wait for bucket to be available
	helpers.WaitForS3Bucket(t, testConfig.Region, bucketName, 10)

	// Validate bucket configuration
	t.Run("ValidateBucketEncryption", func(t *testing.T) {
		helpers.ValidateS3BucketEncryption(t, testConfig.Region, bucketName)
	})

	t.Run("ValidateBucketPublicAccess", func(t *testing.T) {
		// Website buckets should allow some public access
		helpers.ValidateS3BucketPublicAccess(t, testConfig.Region, bucketName, true)
	})

	t.Run("ValidateBucketVersioning", func(t *testing.T) {
		expectedStatus := "Disabled"
		if vars["enable_versioning"].(bool) {
			expectedStatus = "Enabled"
		}
		helpers.ValidateS3BucketVersioning(t, testConfig.Region, bucketName, expectedStatus)
	})
}

func TestS3WebsiteModuleWithVersioning(t *testing.T) {
	t.Parallel()

	// Setup test configuration
	testConfig := helpers.NewTestConfig(t)
	
	// Define test variables with versioning enabled
	vars := map[string]interface{}{
		"bucket_name":       helpers.GenerateTestResourceName("website-versioned", testConfig.UniqueID),
		"enable_versioning": true,
		"environment":       testConfig.Environment,
		"tags": map[string]string{
			"Environment": testConfig.Environment,
			"Testing":     "true",
		},
	}

	// Configure Terraform options
	terraformOptions := testConfig.GetTerraformOptions("../../modules/s3-website", vars)
	
	// Cleanup resources after test
	helpers.CleanupTerraform(t, terraformOptions, testConfig.Cleanup)

	// Run terraform init and apply
	terraform.InitAndApply(t, terraformOptions)

	// Get bucket name for validation
	bucketName := terraform.Output(t, terraformOptions, "bucket_name")
	
	// Wait for bucket to be available
	helpers.WaitForS3Bucket(t, testConfig.Region, bucketName, 10)

	// Validate versioning is enabled
	t.Run("ValidateBucketVersioningEnabled", func(t *testing.T) {
		helpers.ValidateS3BucketVersioning(t, testConfig.Region, bucketName, "Enabled")
	})
}

func TestS3WebsiteModuleValidation(t *testing.T) {
	t.Parallel()

	// Setup test configuration
	testConfig := helpers.NewTestConfig(t)
	
	// Test with invalid bucket name (should fail validation)
	vars := map[string]interface{}{
		"bucket_name":       "Invalid_Bucket_Name_With_Underscores",
		"enable_versioning": false,
		"environment":       testConfig.Environment,
	}

	// Configure Terraform options
	terraformOptions := testConfig.GetTerraformOptions("../../modules/s3-website", vars)

	// This should fail during plan phase due to validation
	_, err := terraform.InitAndPlanE(t, terraformOptions)
	
	// We expect this to fail due to invalid bucket name
	require.Error(t, err)
	assert.Contains(t, err.Error(), "bucket")
}