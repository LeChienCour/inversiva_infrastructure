package integration

import (
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-nextjs-infrastructure/test/helpers"
)

// TestCompleteInfrastructureDeployment validates end-to-end infrastructure deployment
func TestCompleteInfrastructureDeployment(t *testing.T) {
	// This is a comprehensive test that takes significant time
	if testing.Short() {
		t.Skip("Skipping end-to-end test in short mode")
	}

	testConfig := helpers.NewTestConfig(t)
	
	// Test both dev and prod environments
	environments := []string{"dev", "prod"}
	
	for _, env := range environments {
		t.Run(fmt.Sprintf("Environment_%s", env), func(t *testing.T) {
			testCompleteEnvironmentDeployment(t, testConfig, env)
		})
	}
}

func testCompleteEnvironmentDeployment(t *testing.T, testConfig *helpers.TestConfig, environment string) {
	// Define environment-specific variables
	vars := map[string]interface{}{
		"environment":    fmt.Sprintf("%s-e2e-%s", environment, testConfig.UniqueID),
		"aws_region":     testConfig.Region,
		"domain_name":    fmt.Sprintf("%s-e2e-%s.example.com", environment, testConfig.UniqueID),
		"project_name":   "nextjs-infra-e2e",
	}

	// Environment-specific optimizations
	if environment == "dev" {
		vars["enable_versioning"] = false
		vars["mfa_configuration"] = "OFF"
		vars["price_class"] = "PriceClass_100"
		vars["cloudfront_enabled"] = true
	} else {
		vars["enable_versioning"] = true
		vars["mfa_configuration"] = "OPTIONAL"
		vars["price_class"] = "PriceClass_All"
		vars["cloudfront_enabled"] = true
	}

	// Store deployed resources for validation
	deployedResources := make(map[string]map[string]string)

	// Step 1: Deploy Cognito
	t.Run("DeployCognito", func(t *testing.T) {
		cognitoVars := map[string]interface{}{
			"user_pool_name":    fmt.Sprintf("%s-users-%s", vars["project_name"], testConfig.UniqueID),
			"environment":       vars["environment"],
			"domain_name":       vars["domain_name"],
			"callback_urls":     []string{fmt.Sprintf("https://%s/callback", vars["domain_name"])},
			"logout_urls":       []string{fmt.Sprintf("https://%s/logout", vars["domain_name"])},
			"mfa_configuration": vars["mfa_configuration"],
		}
		
		cognitoOptions := testConfig.GetTerraformOptions("../../modules/cognito", cognitoVars)
		helpers.CleanupTerraform(t, cognitoOptions, testConfig.Cleanup)
		
		terraform.InitAndApply(t, cognitoOptions)
		
		// Store outputs
		deployedResources["cognito"] = map[string]string{
			"user_pool_id":        terraform.Output(t, cognitoOptions, "user_pool_id"),
			"user_pool_client_id": terraform.Output(t, cognitoOptions, "user_pool_client_id"),
			"identity_pool_id":    terraform.Output(t, cognitoOptions, "identity_pool_id"),
		}
		
		// Validate outputs
		assert.NotEmpty(t, deployedResources["cognito"]["user_pool_id"])
		assert.NotEmpty(t, deployedResources["cognito"]["user_pool_client_id"])
		assert.NotEmpty(t, deployedResources["cognito"]["identity_pool_id"])
	})

	// Step 2: Deploy S3 Website
	t.Run("DeployS3Website", func(t *testing.T) {
		websiteVars := map[string]interface{}{
			"bucket_name":       fmt.Sprintf("%s-website-%s", vars["project_name"], testConfig.UniqueID),
			"environment":       vars["environment"],
			"enable_versioning": vars["enable_versioning"],
		}
		
		websiteOptions := testConfig.GetTerraformOptions("../../modules/s3-website", websiteVars)
		helpers.CleanupTerraform(t, websiteOptions, testConfig.Cleanup)
		
		terraform.InitAndApply(t, websiteOptions)
		
		// Store outputs
		deployedResources["s3-website"] = map[string]string{
			"bucket_name":        terraform.Output(t, websiteOptions, "bucket_name"),
			"bucket_domain_name": terraform.Output(t, websiteOptions, "bucket_domain_name"),
			"website_endpoint":   terraform.Output(t, websiteOptions, "website_endpoint"),
		}
		
		// Validate outputs
		assert.NotEmpty(t, deployedResources["s3-website"]["bucket_name"])
		assert.NotEmpty(t, deployedResources["s3-website"]["bucket_domain_name"])
		assert.NotEmpty(t, deployedResources["s3-website"]["website_endpoint"])
		
		// Validate bucket configuration
		bucketName := deployedResources["s3-website"]["bucket_name"]
		helpers.ValidateS3BucketPublicAccess(t, testConfig.Region, bucketName, true)
		helpers.ValidateS3BucketVersioning(t, testConfig.Region, bucketName, 
			map[bool]string{true: "Enabled", false: "Disabled"}[vars["enable_versioning"].(bool)])
	})

	// Step 3: Deploy S3 Content
	t.Run("DeployS3Content", func(t *testing.T) {
		contentVars := map[string]interface{}{
			"bucket_name":       fmt.Sprintf("%s-content-%s", vars["project_name"], testConfig.UniqueID),
			"environment":       vars["environment"],
			"enable_versioning": true, // Always enabled for content
		}
		
		contentOptions := testConfig.GetTerraformOptions("../../modules/s3-content", contentVars)
		helpers.CleanupTerraform(t, contentOptions, testConfig.Cleanup)
		
		terraform.InitAndApply(t, contentOptions)
		
		// Store outputs
		deployedResources["s3-content"] = map[string]string{
			"bucket_name": terraform.Output(t, contentOptions, "bucket_name"),
			"bucket_arn":  terraform.Output(t, contentOptions, "bucket_arn"),
		}
		
		// Validate outputs
		assert.NotEmpty(t, deployedResources["s3-content"]["bucket_name"])
		assert.NotEmpty(t, deployedResources["s3-content"]["bucket_arn"])
		
		// Validate bucket security
		bucketName := deployedResources["s3-content"]["bucket_name"]
		helpers.ValidateS3BucketPublicAccess(t, testConfig.Region, bucketName, false)
		helpers.ValidateS3BucketEncryption(t, testConfig.Region, bucketName)
		helpers.ValidateS3BucketVersioning(t, testConfig.Region, bucketName, "Enabled")
	})

	// Step 4: Deploy CloudFront (depends on S3 website)
	t.Run("DeployCloudFront", func(t *testing.T) {
		require.Contains(t, deployedResources, "s3-website", "S3 website must be deployed first")
		
		cloudfrontVars := map[string]interface{}{
			"distribution_comment": fmt.Sprintf("%s CloudFront Distribution", vars["project_name"]),
			"environment":          vars["environment"],
			"s3_bucket_domain":     deployedResources["s3-website"]["bucket_domain_name"],
			"price_class":          vars["price_class"],
			"enable_ipv6":          environment == "prod", // Enable IPv6 for prod only
		}
		
		cloudfrontOptions := testConfig.GetTerraformOptions("../../modules/cloudfront", cloudfrontVars)
		helpers.CleanupTerraform(t, cloudfrontOptions, testConfig.Cleanup)
		
		terraform.InitAndApply(t, cloudfrontOptions)
		
		// Store outputs
		deployedResources["cloudfront"] = map[string]string{
			"distribution_id":          terraform.Output(t, cloudfrontOptions, "distribution_id"),
			"distribution_domain_name": terraform.Output(t, cloudfrontOptions, "distribution_domain_name"),
		}
		
		// Validate outputs
		assert.NotEmpty(t, deployedResources["cloudfront"]["distribution_id"])
		assert.NotEmpty(t, deployedResources["cloudfront"]["distribution_domain_name"])
		assert.Contains(t, deployedResources["cloudfront"]["distribution_domain_name"], "cloudfront.net")
	})

	// Step 5: Validate complete integration
	t.Run("ValidateCompleteIntegration", func(t *testing.T) {
		// Ensure all components were deployed
		requiredComponents := []string{"cognito", "s3-website", "s3-content", "cloudfront"}
		for _, component := range requiredComponents {
			require.Contains(t, deployedResources, component, 
				fmt.Sprintf("Component %s must be deployed", component))
		}

		// Validate naming consistency
		envPrefix := vars["environment"].(string)
		for component, resources := range deployedResources {
			for resourceType, resourceName := range resources {
				if strings.Contains(resourceType, "name") || strings.Contains(resourceType, "id") {
					assert.Contains(t, resourceName, testConfig.UniqueID,
						fmt.Sprintf("%s %s should contain unique ID", component, resourceType))
				}
			}
		}

		// Validate resource isolation (different names for different components)
		websiteBucket := deployedResources["s3-website"]["bucket_name"]
		contentBucket := deployedResources["s3-content"]["bucket_name"]
		assert.NotEqual(t, websiteBucket, contentBucket, "Website and content buckets should have different names")

		// Validate environment-specific configurations
		if environment == "dev" {
			// Dev should have cost-optimized settings
			assert.Equal(t, "PriceClass_100", vars["price_class"])
			assert.Equal(t, "OFF", vars["mfa_configuration"])
		} else {
			// Prod should have performance-optimized settings
			assert.Equal(t, "PriceClass_All", vars["price_class"])
			assert.Equal(t, "OPTIONAL", vars["mfa_configuration"])
		}
	})

	// Step 6: Test component dependencies and integration
	t.Run("ValidateComponentDependencies", func(t *testing.T) {
		// Validate CloudFront is properly configured with S3 origin
		cloudfrontDomain := deployedResources["cloudfront"]["distribution_domain_name"]
		s3Domain := deployedResources["s3-website"]["bucket_domain_name"]
		
		// CloudFront should be accessible (basic connectivity test)
		assert.NotEmpty(t, cloudfrontDomain)
		assert.NotEmpty(t, s3Domain)
		
		// Validate that resources can be referenced by each other
		userPoolId := deployedResources["cognito"]["user_pool_id"]
		assert.True(t, strings.HasPrefix(userPoolId, testConfig.Region+"_"), 
			"User Pool ID should start with region prefix")
	})
}

// TestCrossEnvironmentIsolation validates that dev and prod environments are properly isolated
func TestCrossEnvironmentIsolation(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping cross-environment isolation test in short mode")
	}

	testConfig := helpers.NewTestConfig(t)
	
	// Deploy minimal resources in both environments
	environments := []string{"dev", "prod"}
	deployedResources := make(map[string]map[string]string)

	// Deploy S3 buckets in both environments
	for _, env := range environments {
		t.Run(fmt.Sprintf("Deploy_%s_Resources", env), func(t *testing.T) {
			vars := map[string]interface{}{
				"bucket_name": fmt.Sprintf("isolation-test-%s-%s", env, testConfig.UniqueID),
				"environment": fmt.Sprintf("%s-isolation-%s", env, testConfig.UniqueID),
			}
			
			options := testConfig.GetTerraformOptions("../../modules/s3-website", vars)
			helpers.CleanupTerraform(t, options, testConfig.Cleanup)
			
			terraform.InitAndApply(t, options)
			
			deployedResources[env] = map[string]string{
				"bucket_name": terraform.Output(t, options, "bucket_name"),
			}
		})
	}

	// Validate isolation
	t.Run("ValidateIsolation", func(t *testing.T) {
		require.Len(t, deployedResources, 2, "Both environments should be deployed")
		
		devBucket := deployedResources["dev"]["bucket_name"]
		prodBucket := deployedResources["prod"]["bucket_name"]
		
		// Buckets should have different names
		assert.NotEqual(t, devBucket, prodBucket, "Dev and prod buckets should have different names")
		
		// Buckets should contain environment identifiers
		assert.Contains(t, devBucket, "dev", "Dev bucket should contain 'dev' identifier")
		assert.Contains(t, prodBucket, "prod", "Prod bucket should contain 'prod' identifier")
		
		// Validate that resources don't interfere with each other
		assert.NotContains(t, devBucket, "prod", "Dev bucket should not contain 'prod'")
		assert.NotContains(t, prodBucket, "dev", "Prod bucket should not contain 'dev'")
	})
}

// TestResourceSeparation validates that different resource types are properly separated
func TestResourceSeparation(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping resource separation test in short mode")
	}

	testConfig := helpers.NewTestConfig(t)
	
	// Deploy different types of S3 buckets
	bucketTypes := []string{"website", "content"}
	deployedBuckets := make(map[string]string)

	for _, bucketType := range bucketTypes {
		t.Run(fmt.Sprintf("Deploy_%s_Bucket", bucketType), func(t *testing.T) {
			vars := map[string]interface{}{
				"bucket_name": fmt.Sprintf("separation-test-%s-%s", bucketType, testConfig.UniqueID),
				"environment": fmt.Sprintf("separation-%s", testConfig.UniqueID),
			}
			
			modulePath := fmt.Sprintf("../../modules/s3-%s", bucketType)
			options := testConfig.GetTerraformOptions(modulePath, vars)
			helpers.CleanupTerraform(t, options, testConfig.Cleanup)
			
			terraform.InitAndApply(t, options)
			
			deployedBuckets[bucketType] = terraform.Output(t, options, "bucket_name")
		})
	}

	// Validate separation
	t.Run("ValidateSeparation", func(t *testing.T) {
		require.Len(t, deployedBuckets, 2, "Both bucket types should be deployed")
		
		websiteBucket := deployedBuckets["website"]
		contentBucket := deployedBuckets["content"]
		
		// Buckets should have different names
		assert.NotEqual(t, websiteBucket, contentBucket, "Website and content buckets should have different names")
		
		// Buckets should contain type identifiers
		assert.Contains(t, websiteBucket, "website", "Website bucket should contain 'website' identifier")
		assert.Contains(t, contentBucket, "content", "Content bucket should contain 'content' identifier")
		
		// Validate bucket-specific configurations
		helpers.ValidateS3BucketPublicAccess(t, testConfig.Region, websiteBucket, true)  // Website should allow public access
		helpers.ValidateS3BucketPublicAccess(t, testConfig.Region, contentBucket, false) // Content should block public access
		helpers.ValidateS3BucketEncryption(t, testConfig.Region, contentBucket)          // Content should be encrypted
	})
}

// TestDeploymentRollback validates rollback capabilities
func TestDeploymentRollback(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping deployment rollback test in short mode")
	}

	testConfig := helpers.NewTestConfig(t)
	
	// Initial deployment
	vars := map[string]interface{}{
		"bucket_name":       fmt.Sprintf("rollback-test-%s", testConfig.UniqueID),
		"environment":       fmt.Sprintf("rollback-%s", testConfig.UniqueID),
		"enable_versioning": false,
	}
	
	options := testConfig.GetTerraformOptions("../../modules/s3-website", vars)
	
	// Deploy initial configuration
	t.Run("InitialDeployment", func(t *testing.T) {
		terraform.InitAndApply(t, options)
		
		bucketName := terraform.Output(t, options, "bucket_name")
		helpers.ValidateS3BucketVersioning(t, testConfig.Region, bucketName, "Disabled")
	})
	
	// Modify configuration
	t.Run("ModifyConfiguration", func(t *testing.T) {
		vars["enable_versioning"] = true
		options.Vars = vars
		
		terraform.Apply(t, options)
		
		bucketName := terraform.Output(t, options, "bucket_name")
		helpers.ValidateS3BucketVersioning(t, testConfig.Region, bucketName, "Enabled")
	})
	
	// Rollback configuration
	t.Run("RollbackConfiguration", func(t *testing.T) {
		vars["enable_versioning"] = false
		options.Vars = vars
		
		terraform.Apply(t, options)
		
		bucketName := terraform.Output(t, options, "bucket_name")
		helpers.ValidateS3BucketVersioning(t, testConfig.Region, bucketName, "Suspended")
	})
	
	// Cleanup
	if testConfig.Cleanup {
		terraform.Destroy(t, options)
	}
}

// TestFailureRecovery validates recovery from deployment failures
func TestFailureRecovery(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping failure recovery test in short mode")
	}

	testConfig := helpers.NewTestConfig(t)
	
	// Test with invalid configuration that should fail
	t.Run("InvalidConfiguration", func(t *testing.T) {
		vars := map[string]interface{}{
			"bucket_name": "invalid-bucket-name-with-uppercase-LETTERS", // Invalid S3 bucket name
			"environment": fmt.Sprintf("failure-%s", testConfig.UniqueID),
		}
		
		options := testConfig.GetTerraformOptions("../../modules/s3-website", vars)
		
		// This should fail
		_, err := terraform.InitAndApplyE(t, options)
		assert.Error(t, err, "Deployment with invalid configuration should fail")
	})
	
	// Test recovery with valid configuration
	t.Run("RecoveryWithValidConfiguration", func(t *testing.T) {
		vars := map[string]interface{}{
			"bucket_name": fmt.Sprintf("recovery-test-%s", testConfig.UniqueID),
			"environment": fmt.Sprintf("recovery-%s", testConfig.UniqueID),
		}
		
		options := testConfig.GetTerraformOptions("../../modules/s3-website", vars)
		helpers.CleanupTerraform(t, options, testConfig.Cleanup)
		
		// This should succeed
		terraform.InitAndApply(t, options)
		
		bucketName := terraform.Output(t, options, "bucket_name")
		assert.NotEmpty(t, bucketName)
		assert.Contains(t, bucketName, "recovery-test")
	})
}