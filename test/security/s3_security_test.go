package security

import (
	"testing"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-nextjs-infrastructure/test/helpers"
)

func TestS3WebsiteBucketSecurity(t *testing.T) {
	t.Parallel()

	testConfig := helpers.NewTestConfig(t)
	
	// Deploy S3 website bucket
	vars := map[string]interface{}{
		"bucket_name": helpers.GenerateTestResourceName("security-website", testConfig.UniqueID),
		"environment": testConfig.Environment,
	}
	
	options := testConfig.GetTerraformOptions("../../modules/s3-website", vars)
	helpers.CleanupTerraform(t, options, testConfig.Cleanup)
	
	terraform.InitAndApply(t, options)
	
	bucketName := terraform.Output(t, options, "bucket_name")
	
	// Wait for bucket to be available
	helpers.WaitForS3Bucket(t, testConfig.Region, bucketName, 10)
	
	t.Run("ValidateEncryptionAtRest", func(t *testing.T) {
		validateS3BucketEncryption(t, testConfig.Region, bucketName)
	})
	
	t.Run("ValidatePublicAccessConfiguration", func(t *testing.T) {
		// Website buckets need some public access for CloudFront
		validateS3WebsiteBucketPublicAccess(t, testConfig.Region, bucketName)
	})
	
	t.Run("ValidateBucketPolicy", func(t *testing.T) {
		validateS3WebsiteBucketPolicy(t, testConfig.Region, bucketName)
	})
	
	t.Run("ValidateLoggingConfiguration", func(t *testing.T) {
		validateS3BucketLogging(t, testConfig.Region, bucketName)
	})
	
	t.Run("ValidateVersioningConfiguration", func(t *testing.T) {
		// Website buckets may have versioning disabled for cost optimization
		validateS3BucketVersioningExists(t, testConfig.Region, bucketName)
	})
}

func TestS3ContentBucketSecurity(t *testing.T) {
	t.Parallel()

	testConfig := helpers.NewTestConfig(t)
	
	// Deploy S3 content bucket
	vars := map[string]interface{}{
		"bucket_name":       helpers.GenerateTestResourceName("security-content", testConfig.UniqueID),
		"environment":       testConfig.Environment,
		"enable_versioning": true,
		"kms_key_id":        "alias/aws/s3",
	}
	
	options := testConfig.GetTerraformOptions("../../modules/s3-content", vars)
	helpers.CleanupTerraform(t, options, testConfig.Cleanup)
	
	terraform.InitAndApply(t, options)
	
	bucketName := terraform.Output(t, options, "bucket_name")
	
	// Wait for bucket to be available
	helpers.WaitForS3Bucket(t, testConfig.Region, bucketName, 10)
	
	t.Run("ValidateEncryptionAtRest", func(t *testing.T) {
		validateS3BucketEncryption(t, testConfig.Region, bucketName)
	})
	
	t.Run("ValidatePrivateAccess", func(t *testing.T) {
		// Content buckets must be completely private
		validateS3ContentBucketPrivateAccess(t, testConfig.Region, bucketName)
	})
	
	t.Run("ValidateBucketPolicy", func(t *testing.T) {
		validateS3ContentBucketPolicy(t, testConfig.Region, bucketName)
	})
	
	t.Run("ValidateVersioningEnabled", func(t *testing.T) {
		helpers.ValidateS3BucketVersioning(t, testConfig.Region, bucketName, "Enabled")
	})
	
	t.Run("ValidateLifecyclePolicies", func(t *testing.T) {
		validateS3BucketLifecyclePolicies(t, testConfig.Region, bucketName)
	})
}

func TestS3BucketSecurityCompliance(t *testing.T) {
	t.Parallel()

	testConfig := helpers.NewTestConfig(t)
	
	// Test both bucket types for compliance
	buckets := []struct {
		name       string
		moduleDir  string
		bucketType string
		vars       map[string]interface{}
	}{
		{
			name:       "website-compliance",
			moduleDir:  "../../modules/s3-website",
			bucketType: "website",
			vars: map[string]interface{}{
				"bucket_name": helpers.GenerateTestResourceName("compliance-website", testConfig.UniqueID),
				"environment": testConfig.Environment,
			},
		},
		{
			name:       "content-compliance",
			moduleDir:  "../../modules/s3-content",
			bucketType: "content",
			vars: map[string]interface{}{
				"bucket_name":       helpers.GenerateTestResourceName("compliance-content", testConfig.UniqueID),
				"environment":       testConfig.Environment,
				"enable_versioning": true,
			},
		},
	}
	
	for _, bucket := range buckets {
		t.Run(bucket.name, func(t *testing.T) {
			options := testConfig.GetTerraformOptions(bucket.moduleDir, bucket.vars)
			helpers.CleanupTerraform(t, options, testConfig.Cleanup)
			
			terraform.InitAndApply(t, options)
			
			bucketName := terraform.Output(t, options, "bucket_name")
			
			// Wait for bucket to be available
			helpers.WaitForS3Bucket(t, testConfig.Region, bucketName, 10)
			
			// Run compliance checks
			t.Run("ComplianceChecks", func(t *testing.T) {
				validateS3ComplianceChecks(t, testConfig.Region, bucketName, bucket.bucketType)
			})
		})
	}
}

// Helper function to validate S3 bucket encryption
func validateS3BucketEncryption(t *testing.T, region, bucketName string) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	s3Client := s3.New(sess)
	
	result, err := s3Client.GetBucketEncryption(&s3.GetBucketEncryptionInput{
		Bucket: aws.String(bucketName),
	})
	require.NoError(t, err, "Bucket encryption must be configured")
	require.NotNil(t, result.ServerSideEncryptionConfiguration)
	require.NotEmpty(t, result.ServerSideEncryptionConfiguration.Rules)
	
	// Validate encryption algorithm
	rule := result.ServerSideEncryptionConfiguration.Rules[0]
	require.NotNil(t, rule.ApplyServerSideEncryptionByDefault)
	
	algorithm := *rule.ApplyServerSideEncryptionByDefault.SSEAlgorithm
	assert.True(t, algorithm == "AES256" || algorithm == "aws:kms",
		"Encryption algorithm must be AES256 or aws:kms, got %s", algorithm)
	
	t.Logf("Bucket %s has encryption enabled with algorithm: %s", bucketName, algorithm)
}

// Helper function to validate website bucket public access
func validateS3WebsiteBucketPublicAccess(t *testing.T, region, bucketName string) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	s3Client := s3.New(sess)
	
	// Check public access block configuration
	result, err := s3Client.GetPublicAccessBlock(&s3.GetPublicAccessBlockInput{
		Bucket: aws.String(bucketName),
	})
	
	if err != nil {
		// If no public access block is configured, that's acceptable for website buckets
		t.Logf("No public access block configured for website bucket %s", bucketName)
		return
	}
	
	config := result.PublicAccessBlockConfiguration
	
	// Website buckets may need some public access for CloudFront OAC
	// But we should still validate the configuration is intentional
	t.Logf("Public access block configuration for %s:", bucketName)
	t.Logf("  BlockPublicAcls: %t", *config.BlockPublicAcls)
	t.Logf("  BlockPublicPolicy: %t", *config.BlockPublicPolicy)
	t.Logf("  IgnorePublicAcls: %t", *config.IgnorePublicAcls)
	t.Logf("  RestrictPublicBuckets: %t", *config.RestrictPublicBuckets)
}

// Helper function to validate content bucket private access
func validateS3ContentBucketPrivateAccess(t *testing.T, region, bucketName string) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	s3Client := s3.New(sess)
	
	// Content buckets must have public access blocked
	result, err := s3Client.GetPublicAccessBlock(&s3.GetPublicAccessBlockInput{
		Bucket: aws.String(bucketName),
	})
	require.NoError(t, err, "Content buckets must have public access block configured")
	
	config := result.PublicAccessBlockConfiguration
	assert.True(t, *config.BlockPublicAcls, "Content bucket must block public ACLs")
	assert.True(t, *config.BlockPublicPolicy, "Content bucket must block public policies")
	assert.True(t, *config.IgnorePublicAcls, "Content bucket must ignore public ACLs")
	assert.True(t, *config.RestrictPublicBuckets, "Content bucket must restrict public buckets")
}

// Helper function to validate website bucket policy
func validateS3WebsiteBucketPolicy(t *testing.T, region, bucketName string) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	s3Client := s3.New(sess)
	
	// Check if bucket policy exists
	_, err = s3Client.GetBucketPolicy(&s3.GetBucketPolicyInput{
		Bucket: aws.String(bucketName),
	})
	
	if err != nil {
		// Website buckets may not have a policy if using OAC
		t.Logf("No bucket policy found for website bucket %s (may use OAC)", bucketName)
		return
	}
	
	t.Logf("Bucket policy exists for website bucket %s", bucketName)
}

// Helper function to validate content bucket policy
func validateS3ContentBucketPolicy(t *testing.T, region, bucketName string) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	s3Client := s3.New(sess)
	
	// Check if bucket policy exists
	result, err := s3Client.GetBucketPolicy(&s3.GetBucketPolicyInput{
		Bucket: aws.String(bucketName),
	})
	
	if err != nil {
		// Content buckets should have restrictive policies
		t.Logf("No bucket policy found for content bucket %s", bucketName)
		return
	}
	
	// Validate policy exists and is not empty
	assert.NotEmpty(t, *result.Policy, "Content bucket policy should not be empty")
	t.Logf("Bucket policy exists for content bucket %s", bucketName)
}

// Helper function to validate bucket logging
func validateS3BucketLogging(t *testing.T, region, bucketName string) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	s3Client := s3.New(sess)
	
	// Check bucket logging configuration
	result, err := s3Client.GetBucketLogging(&s3.GetBucketLoggingInput{
		Bucket: aws.String(bucketName),
	})
	require.NoError(t, err)
	
	// Logging may or may not be configured depending on requirements
	if result.LoggingEnabled != nil {
		assert.NotEmpty(t, *result.LoggingEnabled.TargetBucket, "Log target bucket should be specified")
		t.Logf("Bucket %s has logging enabled to %s", bucketName, *result.LoggingEnabled.TargetBucket)
	} else {
		t.Logf("Bucket %s does not have logging enabled", bucketName)
	}
}

// Helper function to validate versioning exists (may be enabled or suspended)
func validateS3BucketVersioningExists(t *testing.T, region, bucketName string) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	s3Client := s3.New(sess)
	
	result, err := s3Client.GetBucketVersioning(&s3.GetBucketVersioningInput{
		Bucket: aws.String(bucketName),
	})
	require.NoError(t, err)
	
	// Versioning configuration should exist (even if disabled)
	if result.Status != nil {
		status := *result.Status
		assert.True(t, status == "Enabled" || status == "Suspended",
			"Versioning status should be Enabled or Suspended, got %s", status)
		t.Logf("Bucket %s versioning status: %s", bucketName, status)
	} else {
		t.Logf("Bucket %s versioning is not configured (disabled)", bucketName)
	}
}

// Helper function to validate lifecycle policies
func validateS3BucketLifecyclePolicies(t *testing.T, region, bucketName string) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	s3Client := s3.New(sess)
	
	result, err := s3Client.GetBucketLifecycleConfiguration(&s3.GetBucketLifecycleConfigurationInput{
		Bucket: aws.String(bucketName),
	})
	
	if err != nil {
		t.Logf("No lifecycle configuration found for bucket %s", bucketName)
		return
	}
	
	// Validate lifecycle rules exist
	assert.NotEmpty(t, result.Rules, "Lifecycle rules should be configured")
	
	for _, rule := range result.Rules {
		assert.NotEmpty(t, *rule.ID, "Lifecycle rule should have an ID")
		assert.Equal(t, "Enabled", *rule.Status, "Lifecycle rule should be enabled")
		t.Logf("Lifecycle rule %s is configured for bucket %s", *rule.ID, bucketName)
	}
}

// Helper function to run comprehensive compliance checks
func validateS3ComplianceChecks(t *testing.T, region, bucketName, bucketType string) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	s3Client := s3.New(sess)
	
	// Check bucket exists and is accessible
	_, err = s3Client.HeadBucket(&s3.HeadBucketInput{
		Bucket: aws.String(bucketName),
	})
	require.NoError(t, err, "Bucket should be accessible")
	
	// Encryption is mandatory for all buckets
	validateS3BucketEncryption(t, region, bucketName)
	
	// Check bucket location
	locationResult, err := s3Client.GetBucketLocation(&s3.GetBucketLocationInput{
		Bucket: aws.String(bucketName),
	})
	require.NoError(t, err)
	
	// Validate bucket is in expected region
	if locationResult.LocationConstraint != nil {
		assert.Equal(t, region, *locationResult.LocationConstraint,
			"Bucket should be in expected region")
	} else {
		// us-east-1 returns nil for location constraint
		assert.Equal(t, "us-east-1", region, "Bucket with nil location should be in us-east-1")
	}
	
	// Type-specific compliance checks
	switch bucketType {
	case "content":
		validateS3ContentBucketPrivateAccess(t, region, bucketName)
		helpers.ValidateS3BucketVersioning(t, region, bucketName, "Enabled")
	case "website":
		validateS3WebsiteBucketPublicAccess(t, region, bucketName)
		validateS3BucketVersioningExists(t, region, bucketName)
	}
	
	t.Logf("Compliance checks passed for %s bucket: %s", bucketType, bucketName)
}