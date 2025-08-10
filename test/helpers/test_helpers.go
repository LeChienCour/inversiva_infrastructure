package helpers

import (
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

// TestConfig holds common test configuration
type TestConfig struct {
	Region      string
	Environment string
	UniqueID    string
	Cleanup     bool
}

// NewTestConfig creates a new test configuration with defaults
func NewTestConfig(t *testing.T) *TestConfig {
	uniqueID := strings.ToLower(random.UniqueId())
	
	return &TestConfig{
		Region:      getEnvOrDefault("AWS_REGION", "us-east-1"),
		Environment: getEnvOrDefault("TEST_ENVIRONMENT", "test"),
		UniqueID:    uniqueID,
		Cleanup:     getEnvOrDefault("CLEANUP_RESOURCES", "true") == "true",
	}
}

// GetTerraformOptions creates standard terraform options for testing
func (tc *TestConfig) GetTerraformOptions(terraformDir string, vars map[string]interface{}) *terraform.Options {
	// Add common variables
	if vars == nil {
		vars = make(map[string]interface{})
	}
	
	vars["environment"] = tc.Environment
	vars["unique_id"] = tc.UniqueID
	vars["aws_region"] = tc.Region
	
	return &terraform.Options{
		TerraformDir: terraformDir,
		Vars:         vars,
		NoColor:      true,
		Reconfigure:  true,
	}
}

// WaitForS3Bucket waits for an S3 bucket to be available
func WaitForS3Bucket(t *testing.T, region, bucketName string, maxRetries int) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	s3Client := s3.New(sess)
	
	for i := 0; i < maxRetries; i++ {
		_, err := s3Client.HeadBucket(&s3.HeadBucketInput{
			Bucket: aws.String(bucketName),
		})
		
		if err == nil {
			return
		}
		
		if i < maxRetries-1 {
			time.Sleep(5 * time.Second)
		}
	}
	
	require.Fail(t, fmt.Sprintf("S3 bucket %s not available after %d retries", bucketName, maxRetries))
}

// ValidateS3BucketEncryption validates that S3 bucket has encryption enabled
func ValidateS3BucketEncryption(t *testing.T, region, bucketName string) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	s3Client := s3.New(sess)
	
	result, err := s3Client.GetBucketEncryption(&s3.GetBucketEncryptionInput{
		Bucket: aws.String(bucketName),
	})
	require.NoError(t, err)
	require.NotNil(t, result.ServerSideEncryptionConfiguration)
	require.NotEmpty(t, result.ServerSideEncryptionConfiguration.Rules)
}

// ValidateS3BucketPublicAccess validates S3 bucket public access settings
func ValidateS3BucketPublicAccess(t *testing.T, region, bucketName string, shouldBePublic bool) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	s3Client := s3.New(sess)
	
	result, err := s3Client.GetPublicAccessBlock(&s3.GetPublicAccessBlockInput{
		Bucket: aws.String(bucketName),
	})
	
	if shouldBePublic {
		// For website buckets, we expect some public access
		if err == nil {
			require.False(t, *result.PublicAccessBlockConfiguration.BlockPublicAcls)
		}
	} else {
		// For content buckets, we expect full public access blocking
		require.NoError(t, err)
		require.True(t, *result.PublicAccessBlockConfiguration.BlockPublicAcls)
		require.True(t, *result.PublicAccessBlockConfiguration.BlockPublicPolicy)
		require.True(t, *result.PublicAccessBlockConfiguration.IgnorePublicAcls)
		require.True(t, *result.PublicAccessBlockConfiguration.RestrictPublicBuckets)
	}
}

// ValidateS3BucketVersioning validates S3 bucket versioning configuration
func ValidateS3BucketVersioning(t *testing.T, region, bucketName string, expectedStatus string) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	s3Client := s3.New(sess)
	
	result, err := s3Client.GetBucketVersioning(&s3.GetBucketVersioningInput{
		Bucket: aws.String(bucketName),
	})
	require.NoError(t, err)
	
	if result.Status != nil {
		require.Equal(t, expectedStatus, *result.Status)
	} else {
		require.Equal(t, "Disabled", expectedStatus)
	}
}

// getEnvOrDefault returns environment variable value or default
func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// GenerateTestResourceName generates a consistent test resource name
func GenerateTestResourceName(prefix, uniqueID string) string {
	return fmt.Sprintf("%s-test-%s", prefix, uniqueID)
}

// CleanupTerraform performs terraform destroy if cleanup is enabled
func CleanupTerraform(t *testing.T, options *terraform.Options, cleanup bool) {
	if cleanup {
		defer terraform.Destroy(t, options)
	}
}