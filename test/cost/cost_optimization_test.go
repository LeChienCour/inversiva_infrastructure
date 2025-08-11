package cost

import (
	"testing"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/cloudfront"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-nextjs-infrastructure/test/helpers"
)

func TestDevEnvironmentCostOptimization(t *testing.T) {
	t.Parallel()

	testConfig := helpers.NewTestConfig(t)
	
	// Test cost-optimized S3 configuration for dev environment
	t.Run("TestS3CostOptimization", func(t *testing.T) {
		vars := map[string]interface{}{
			"bucket_name":       helpers.GenerateTestResourceName("cost-s3", testConfig.UniqueID),
			"environment":       "dev",
			"enable_versioning": false, // Cost optimization for dev
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
					"expiration": map[string]interface{}{
						"days": 365, // Delete after 1 year for dev
					},
				},
			},
		}
		
		options := testConfig.GetTerraformOptions("../../modules/s3-content", vars)
		helpers.CleanupTerraform(t, options, testConfig.Cleanup)
		
		terraform.InitAndApply(t, options)
		
		bucketName := terraform.Output(t, options, "bucket_name")
		
		// Wait for bucket to be available
		helpers.WaitForS3Bucket(t, testConfig.Region, bucketName, 10)
		
		// Validate cost optimization settings
		validateS3CostOptimization(t, testConfig.Region, bucketName, "dev")
	})
	
	// Test cost-optimized CloudFront configuration for dev environment
	t.Run("TestCloudFrontCostOptimization", func(t *testing.T) {
		vars := map[string]interface{}{
			"distribution_comment": "Cost Optimized Dev Distribution",
			"environment":          "dev",
			"s3_bucket_domain":     "test-bucket.s3.amazonaws.com",
			"price_class":          "PriceClass_100", // Cost optimization
			"enable_ipv6":          false, // Simplified for dev
			"default_ttl":          86400, // 1 day caching
			"max_ttl":              31536000, // 1 year max
		}
		
		options := testConfig.GetTerraformOptions("../../modules/cloudfront", vars)
		helpers.CleanupTerraform(t, options, testConfig.Cleanup)
		
		terraform.InitAndApply(t, options)
		
		distributionId := terraform.Output(t, options, "distribution_id")
		
		// Validate cost optimization settings
		validateCloudFrontCostOptimization(t, testConfig.Region, distributionId, "dev")
	})
}

func TestProductionCostOptimization(t *testing.T) {
	t.Parallel()

	testConfig := helpers.NewTestConfig(t)
	
	// Test production S3 configuration with balanced cost/performance
	t.Run("TestS3ProductionOptimization", func(t *testing.T) {
		vars := map[string]interface{}{
			"bucket_name":       helpers.GenerateTestResourceName("cost-prod-s3", testConfig.UniqueID),
			"environment":       "prod",
			"enable_versioning": true, // Required for prod
			"lifecycle_rules": []map[string]interface{}{
				{
					"id":     "prod_cost_optimization",
					"status": "Enabled",
					"transition": []map[string]interface{}{
						{
							"days":          90,
							"storage_class": "STANDARD_IA",
						},
						{
							"days":          180,
							"storage_class": "GLACIER",
						},
						{
							"days":          365,
							"storage_class": "DEEP_ARCHIVE",
						},
					},
					"noncurrent_version_transition": []map[string]interface{}{
						{
							"days":          30,
							"storage_class": "STANDARD_IA",
						},
						{
							"days":          60,
							"storage_class": "GLACIER",
						},
					},
					"noncurrent_version_expiration": map[string]interface{}{
						"days": 90, // Keep old versions for 90 days
					},
				},
			},
		}
		
		options := testConfig.GetTerraformOptions("../../modules/s3-content", vars)
		helpers.CleanupTerraform(t, options, testConfig.Cleanup)
		
		terraform.InitAndApply(t, options)
		
		bucketName := terraform.Output(t, options, "bucket_name")
		
		// Wait for bucket to be available
		helpers.WaitForS3Bucket(t, testConfig.Region, bucketName, 10)
		
		// Validate production cost optimization settings
		validateS3CostOptimization(t, testConfig.Region, bucketName, "prod")
	})
	
	// Test production CloudFront configuration
	t.Run("TestCloudFrontProductionOptimization", func(t *testing.T) {
		vars := map[string]interface{}{
			"distribution_comment": "Production Distribution",
			"environment":          "prod",
			"s3_bucket_domain":     "prod-bucket.s3.amazonaws.com",
			"price_class":          "PriceClass_All", // Global distribution for prod
			"enable_ipv6":          true, // Full features for prod
			"default_ttl":          3600, // 1 hour caching
			"max_ttl":              86400, // 1 day max
		}
		
		options := testConfig.GetTerraformOptions("../../modules/cloudfront", vars)
		helpers.CleanupTerraform(t, options, testConfig.Cleanup)
		
		terraform.InitAndApply(t, options)
		
		distributionId := terraform.Output(t, options, "distribution_id")
		
		// Validate production optimization settings
		validateCloudFrontCostOptimization(t, testConfig.Region, distributionId, "prod")
	})
}

func TestCostOptimizationBestPractices(t *testing.T) {
	t.Parallel()

	testConfig := helpers.NewTestConfig(t)
	
	// Test comprehensive cost optimization across multiple resources
	t.Run("TestComprehensiveCostOptimization", func(t *testing.T) {
		// Deploy website bucket with cost optimization
		websiteVars := map[string]interface{}{
			"bucket_name":       helpers.GenerateTestResourceName("cost-website", testConfig.UniqueID),
			"environment":       "dev",
			"enable_versioning": false, // Cost optimization
		}
		
		websiteOptions := testConfig.GetTerraformOptions("../../modules/s3-website", websiteVars)
		helpers.CleanupTerraform(t, websiteOptions, testConfig.Cleanup)
		
		terraform.InitAndApply(t, websiteOptions)
		
		websiteBucket := terraform.Output(t, websiteOptions, "bucket_name")
		bucketDomain := terraform.Output(t, websiteOptions, "bucket_domain_name")
		
		// Deploy content bucket with lifecycle policies
		contentVars := map[string]interface{}{
			"bucket_name": helpers.GenerateTestResourceName("cost-content", testConfig.UniqueID),
			"environment": "dev",
			"lifecycle_rules": []map[string]interface{}{
				{
					"id":     "aggressive_cost_optimization",
					"status": "Enabled",
					"transition": []map[string]interface{}{
						{
							"days":          7,
							"storage_class": "STANDARD_IA",
						},
						{
							"days":          30,
							"storage_class": "GLACIER",
						},
					},
					"expiration": map[string]interface{}{
						"days": 180, // Aggressive cleanup for dev
					},
				},
			},
		}
		
		contentOptions := testConfig.GetTerraformOptions("../../modules/s3-content", contentVars)
		helpers.CleanupTerraform(t, contentOptions, testConfig.Cleanup)
		
		terraform.InitAndApply(t, contentOptions)
		
		contentBucket := terraform.Output(t, contentOptions, "bucket_name")
		
		// Deploy CloudFront with cost optimization
		cloudfrontVars := map[string]interface{}{
			"distribution_comment": "Cost Optimized Distribution",
			"environment":          "dev",
			"s3_bucket_domain":     bucketDomain,
			"price_class":          "PriceClass_100",
			"enable_ipv6":          false,
		}
		
		cloudfrontOptions := testConfig.GetTerraformOptions("../../modules/cloudfront", cloudfrontVars)
		helpers.CleanupTerraform(t, cloudfrontOptions, testConfig.Cleanup)
		
		terraform.InitAndApply(t, cloudfrontOptions)
		
		distributionId := terraform.Output(t, cloudfrontOptions, "distribution_id")
		
		// Wait for resources to be available
		helpers.WaitForS3Bucket(t, testConfig.Region, websiteBucket, 10)
		helpers.WaitForS3Bucket(t, testConfig.Region, contentBucket, 10)
		
		// Validate comprehensive cost optimization
		validateComprehensiveCostOptimization(t, testConfig.Region, websiteBucket, contentBucket, distributionId)
	})
}

// Helper function to validate S3 cost optimization
func validateS3CostOptimization(t *testing.T, region, bucketName, environment string) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	s3Client := s3.New(sess)
	
	// Validate lifecycle configuration exists
	lifecycleResult, err := s3Client.GetBucketLifecycleConfiguration(&s3.GetBucketLifecycleConfigurationInput{
		Bucket: aws.String(bucketName),
	})
	
	if err != nil {
		t.Logf("No lifecycle configuration found for bucket %s", bucketName)
		return
	}
	
	require.NotEmpty(t, lifecycleResult.Rules, "Lifecycle rules should be configured for cost optimization")
	
	for _, rule := range lifecycleResult.Rules {
		assert.Equal(t, "Enabled", *rule.Status, "Lifecycle rule should be enabled")
		
		// Validate transitions exist for cost optimization
		if rule.Transitions != nil && len(rule.Transitions) > 0 {
			for _, transition := range rule.Transitions {
				assert.True(t, *transition.Days > 0, "Transition days should be positive")
				
				storageClass := *transition.StorageClass
				assert.True(t, 
					storageClass == "STANDARD_IA" || 
					storageClass == "GLACIER" || 
					storageClass == "DEEP_ARCHIVE",
					"Storage class should be cost-optimized: %s", storageClass)
			}
			t.Logf("Bucket %s has %d lifecycle transitions configured", bucketName, len(rule.Transitions))
		}
		
		// Validate expiration for dev environments
		if environment == "dev" && rule.Expiration != nil {
			assert.True(t, *rule.Expiration.Days <= 365,
				"Dev environment should have aggressive expiration policy")
			t.Logf("Bucket %s has expiration set to %d days", bucketName, *rule.Expiration.Days)
		}
		
		// Validate non-current version management for versioned buckets
		if rule.NoncurrentVersionTransitions != nil {
			for _, transition := range rule.NoncurrentVersionTransitions {
				assert.True(t, *transition.NoncurrentDays > 0,
					"Non-current version transition days should be positive")
			}
			t.Logf("Bucket %s has non-current version transitions configured", bucketName)
		}
	}
	
	// Validate versioning configuration based on environment
	versioningResult, err := s3Client.GetBucketVersioning(&s3.GetBucketVersioningInput{
		Bucket: aws.String(bucketName),
	})
	require.NoError(t, err)
	
	if environment == "dev" {
		// Dev environments should have versioning disabled or suspended for cost optimization
		if versioningResult.Status != nil {
			status := *versioningResult.Status
			assert.True(t, status == "Suspended" || status == "Disabled",
				"Dev environment should have versioning disabled for cost optimization")
		}
	} else if environment == "prod" {
		// Production should have versioning enabled but with lifecycle management
		if versioningResult.Status != nil {
			assert.Equal(t, "Enabled", *versioningResult.Status,
				"Production environment should have versioning enabled")
		}
	}
	
	t.Logf("S3 cost optimization validated for %s environment bucket: %s", environment, bucketName)
}

// Helper function to validate CloudFront cost optimization
func validateCloudFrontCostOptimization(t *testing.T, region, distributionId, environment string) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	cloudfrontClient := cloudfront.New(sess)
	
	result, err := cloudfrontClient.GetDistribution(&cloudfront.GetDistributionInput{
		Id: aws.String(distributionId),
	})
	require.NoError(t, err)
	require.NotNil(t, result.Distribution)
	
	distribution := result.Distribution.DistributionConfig
	
	// Validate price class based on environment
	priceClass := *distribution.PriceClass
	if environment == "dev" {
		assert.Equal(t, "PriceClass_100", priceClass,
			"Dev environment should use PriceClass_100 for cost optimization")
	} else if environment == "prod" {
		assert.True(t, priceClass == "PriceClass_200" || priceClass == "PriceClass_All",
			"Production environment should use PriceClass_200 or PriceClass_All")
	}
	
	// Validate caching configuration for cost optimization
	defaultBehavior := distribution.DefaultCacheBehavior
	require.NotNil(t, defaultBehavior)
	
	// Validate TTL settings
	if defaultBehavior.DefaultTTL != nil {
		ttl := *defaultBehavior.DefaultTTL
		assert.True(t, ttl > 0, "Default TTL should be positive for cost optimization")
		
		if environment == "dev" {
			assert.True(t, ttl >= 3600, "Dev environment should have reasonable caching (>= 1 hour)")
		}
	}
	
	// Validate compression is enabled for cost optimization
	assert.True(t, *defaultBehavior.Compress, "Compression should be enabled for cost optimization")
	
	// Validate viewer protocol policy (HTTPS reduces costs by improving caching)
	assert.Equal(t, "redirect-to-https", *defaultBehavior.ViewerProtocolPolicy,
		"Should redirect to HTTPS for better caching efficiency")
	
	// Validate IPv6 configuration based on environment
	if environment == "dev" {
		// IPv6 can be disabled for dev to reduce complexity and potential costs
		ipv6Enabled := *distribution.IsIPV6Enabled
		t.Logf("IPv6 enabled for dev environment: %t", ipv6Enabled)
	} else if environment == "prod" {
		// Production should have IPv6 enabled for better global reach
		assert.True(t, *distribution.IsIPV6Enabled,
			"Production should have IPv6 enabled for global reach")
	}
	
	t.Logf("CloudFront cost optimization validated for %s environment distribution: %s", 
		environment, distributionId)
}

// Helper function to validate comprehensive cost optimization
func validateComprehensiveCostOptimization(t *testing.T, region, websiteBucket, contentBucket, distributionId string) {
	// Validate website bucket cost optimization
	validateS3CostOptimization(t, region, websiteBucket, "dev")
	
	// Validate content bucket cost optimization
	validateS3CostOptimization(t, region, contentBucket, "dev")
	
	// Validate CloudFront cost optimization
	validateCloudFrontCostOptimization(t, region, distributionId, "dev")
	
	// Additional cross-resource cost optimization checks
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	s3Client := s3.New(sess)
	
	// Validate that website and content buckets have different configurations
	websiteVersioning, err := s3Client.GetBucketVersioning(&s3.GetBucketVersioningInput{
		Bucket: aws.String(websiteBucket),
	})
	require.NoError(t, err)
	
	contentVersioning, err := s3Client.GetBucketVersioning(&s3.GetBucketVersioningInput{
		Bucket: aws.String(contentBucket),
	})
	require.NoError(t, err)
	
	// Website bucket should have versioning disabled for cost optimization
	if websiteVersioning.Status != nil {
		assert.True(t, *websiteVersioning.Status != "Enabled",
			"Website bucket should not have versioning enabled for cost optimization")
	}
	
	// Content bucket may have versioning based on requirements
	t.Logf("Website bucket versioning: %v", websiteVersioning.Status)
	t.Logf("Content bucket versioning: %v", contentVersioning.Status)
	
	// Validate bucket naming follows cost-effective patterns
	assert.Contains(t, websiteBucket, "website", "Website bucket should be clearly identified")
	assert.Contains(t, contentBucket, "content", "Content bucket should be clearly identified")
	
	t.Logf("Comprehensive cost optimization validation completed for resources")
}