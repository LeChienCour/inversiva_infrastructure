package modules

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-nextjs-infrastructure/test/helpers"
)

func TestS3ContentModule(t *testing.T) {
	t.Parallel()

	// Setup test configuration
	testConfig := helpers.NewTestConfig(t)
	
	// Define test variables
	vars := map[string]interface{}{
		"bucket_name":       helpers.GenerateTestResourceName("content", testConfig.UniqueID),
		"enable_versioning": true,
		"environment":       testConfig.Environment,
		"lifecycle_rules": []map[string]interface{}{
			{
				"id":     "transition_to_ia",
				"status": "Enabled",
				"transition": []map[string]interface{}{
					{
						"days":          30,
						"storage_class": "STANDARD_IA",
					},
				},
			},
		},
		"tags": map[string]string{
			"Environment": testConfig.Environment,
			"Testing":     "true",
		},
	}

	// Configure Terraform options
	terraformOptions := testConfig.GetTerraformOptions("../../modules/s3-content", vars)
	
	// Cleanup resources after test
	helpers.CleanupTerraform(t, terraformOptions, testConfig.Cleanup)

	// Run terraform init and apply
	terraform.InitAndApply(t, terraformOptions)

	// Validate outputs
	bucketName := terraform.Output(t, terraformOptions, "bucket_name")
	bucketArn := terraform.Output(t, terraformOptions, "bucket_arn")
	presignedUrlRoleArn := terraform.Output(t, terraformOptions, "presigned_url_role_arn")

	// Assertions
	assert.NotEmpty(t, bucketName)
	assert.NotEmpty(t, bucketArn)
	assert.NotEmpty(t, presignedUrlRoleArn)
	assert.Contains(t, bucketArn, bucketName)
	assert.Contains(t, presignedUrlRoleArn, "role")

	// Wait for bucket to be available
	helpers.WaitForS3Bucket(t, testConfig.Region, bucketName, 10)

	// Validate bucket security configuration
	t.Run("ValidateBucketEncryption", func(t *testing.T) {
		helpers.ValidateS3BucketEncryption(t, testConfig.Region, bucketName)
	})

	t.Run("ValidateBucketPrivateAccess", func(t *testing.T) {
		// Content buckets should be private
		helpers.ValidateS3BucketPublicAccess(t, testConfig.Region, bucketName, false)
	})

	t.Run("ValidateBucketVersioning", func(t *testing.T) {
		helpers.ValidateS3BucketVersioning(t, testConfig.Region, bucketName, "Enabled")
	})
}

func TestS3ContentModuleMinimalConfig(t *testing.T) {
	t.Parallel()

	// Setup test configuration
	testConfig := helpers.NewTestConfig(t)
	
	// Define minimal test variables
	vars := map[string]interface{}{
		"bucket_name": helpers.GenerateTestResourceName("content-minimal", testConfig.UniqueID),
		"environment": testConfig.Environment,
	}

	// Configure Terraform options
	terraformOptions := testConfig.GetTerraformOptions("../../modules/s3-content", vars)
	
	// Cleanup resources after test
	helpers.CleanupTerraform(t, terraformOptions, testConfig.Cleanup)

	// Run terraform init and apply
	terraform.InitAndApply(t, terraformOptions)

	// Validate outputs exist
	bucketName := terraform.Output(t, terraformOptions, "bucket_name")
	bucketArn := terraform.Output(t, terraformOptions, "bucket_arn")

	// Basic assertions
	assert.NotEmpty(t, bucketName)
	assert.NotEmpty(t, bucketArn)

	// Wait for bucket to be available
	helpers.WaitForS3Bucket(t, testConfig.Region, bucketName, 10)

	// Validate default security settings
	t.Run("ValidateDefaultSecurity", func(t *testing.T) {
		helpers.ValidateS3BucketEncryption(t, testConfig.Region, bucketName)
		helpers.ValidateS3BucketPublicAccess(t, testConfig.Region, bucketName, false)
	})
}

func TestS3ContentModuleWithCustomKMSKey(t *testing.T) {
	t.Parallel()

	// Setup test configuration
	testConfig := helpers.NewTestConfig(t)
	
	// Define test variables with KMS encryption
	vars := map[string]interface{}{
		"bucket_name":    helpers.GenerateTestResourceName("content-kms", testConfig.UniqueID),
		"environment":    testConfig.Environment,
		"kms_key_id":     "alias/aws/s3", // Use AWS managed key for testing
		"enable_versioning": false,
	}

	// Configure Terraform options
	terraformOptions := testConfig.GetTerraformOptions("../../modules/s3-content", vars)
	
	// Cleanup resources after test
	helpers.CleanupTerraform(t, terraformOptions, testConfig.Cleanup)

	// Run terraform init and apply
	terraform.InitAndApply(t, terraformOptions)

	// Validate outputs
	bucketName := terraform.Output(t, terraformOptions, "bucket_name")
	
	// Wait for bucket to be available
	helpers.WaitForS3Bucket(t, testConfig.Region, bucketName, 10)

	// Validate KMS encryption is configured
	t.Run("ValidateKMSEncryption", func(t *testing.T) {
		helpers.ValidateS3BucketEncryption(t, testConfig.Region, bucketName)
	})

	t.Run("ValidateVersioningDisabled", func(t *testing.T) {
		helpers.ValidateS3BucketVersioning(t, testConfig.Region, bucketName, "Disabled")
	})
}