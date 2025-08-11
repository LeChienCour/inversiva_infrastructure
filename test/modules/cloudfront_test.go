package modules

import (
	"testing"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/cloudfront"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-nextjs-infrastructure/test/helpers"
)

func TestCloudFrontModule(t *testing.T) {
	t.Parallel()

	// Setup test configuration
	testConfig := helpers.NewTestConfig(t)
	
	// Define test variables
	vars := map[string]interface{}{
		"distribution_comment": helpers.GenerateTestResourceName("cloudfront", testConfig.UniqueID),
		"environment":          testConfig.Environment,
		"domain_name":          "example.com",
		"s3_bucket_domain":     "example-bucket.s3.amazonaws.com",
		"price_class":          "PriceClass_100",
		"enable_ipv6":          true,
		"default_root_object":  "index.html",
		"custom_error_responses": []map[string]interface{}{
			{
				"error_code":         404,
				"response_code":      200,
				"response_page_path": "/index.html",
			},
		},
		"tags": map[string]string{
			"Environment": testConfig.Environment,
			"Testing":     "true",
		},
	}

	// Configure Terraform options
	terraformOptions := testConfig.GetTerraformOptions("../../modules/cloudfront", vars)
	
	// Cleanup resources after test
	helpers.CleanupTerraform(t, terraformOptions, testConfig.Cleanup)

	// Run terraform init and apply
	terraform.InitAndApply(t, terraformOptions)

	// Validate outputs
	distributionId := terraform.Output(t, terraformOptions, "distribution_id")
	distributionArn := terraform.Output(t, terraformOptions, "distribution_arn")
	distributionDomainName := terraform.Output(t, terraformOptions, "distribution_domain_name")
	distributionHostedZoneId := terraform.Output(t, terraformOptions, "distribution_hosted_zone_id")

	// Assertions
	assert.NotEmpty(t, distributionId)
	assert.NotEmpty(t, distributionArn)
	assert.NotEmpty(t, distributionDomainName)
	assert.NotEmpty(t, distributionHostedZoneId)
	assert.Contains(t, distributionArn, distributionId)
	assert.Contains(t, distributionDomainName, "cloudfront.net")

	// Validate CloudFront distribution configuration
	t.Run("ValidateDistributionConfiguration", func(t *testing.T) {
		validateDistributionConfiguration(t, testConfig.Region, distributionId, vars)
	})

	t.Run("ValidateSecurityHeaders", func(t *testing.T) {
		validateSecurityHeaders(t, testConfig.Region, distributionId)
	})
}

func TestCloudFrontModuleWithCustomDomain(t *testing.T) {
	t.Parallel()

	// Setup test configuration
	testConfig := helpers.NewTestConfig(t)
	
	// Define test variables with custom domain
	vars := map[string]interface{}{
		"distribution_comment": helpers.GenerateTestResourceName("cloudfront-custom", testConfig.UniqueID),
		"environment":          testConfig.Environment,
		"domain_name":          "test.example.com",
		"s3_bucket_domain":     "test-bucket.s3.amazonaws.com",
		"price_class":          "PriceClass_All",
		"enable_ipv6":          false,
		"acm_certificate_arn":  "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012",
		"aliases":              []string{"test.example.com", "www.test.example.com"},
	}

	// Configure Terraform options
	terraformOptions := testConfig.GetTerraformOptions("../../modules/cloudfront", vars)
	
	// Cleanup resources after test
	helpers.CleanupTerraform(t, terraformOptions, testConfig.Cleanup)

	// Run terraform init and apply
	terraform.InitAndApply(t, terraformOptions)

	// Validate custom domain configuration
	distributionId := terraform.Output(t, terraformOptions, "distribution_id")
	
	t.Run("ValidateCustomDomainConfiguration", func(t *testing.T) {
		validateCustomDomainConfiguration(t, testConfig.Region, distributionId, vars)
	})
}

func TestCloudFrontModuleMinimalConfig(t *testing.T) {
	t.Parallel()

	// Setup test configuration
	testConfig := helpers.NewTestConfig(t)
	
	// Define minimal test variables
	vars := map[string]interface{}{
		"distribution_comment": helpers.GenerateTestResourceName("cloudfront-minimal", testConfig.UniqueID),
		"environment":          testConfig.Environment,
		"s3_bucket_domain":     "minimal-bucket.s3.amazonaws.com",
	}

	// Configure Terraform options
	terraformOptions := testConfig.GetTerraformOptions("../../modules/cloudfront", vars)
	
	// Cleanup resources after test
	helpers.CleanupTerraform(t, terraformOptions, testConfig.Cleanup)

	// Run terraform init and apply
	terraform.InitAndApply(t, terraformOptions)

	// Validate basic outputs exist
	distributionId := terraform.Output(t, terraformOptions, "distribution_id")
	distributionDomainName := terraform.Output(t, terraformOptions, "distribution_domain_name")

	assert.NotEmpty(t, distributionId)
	assert.NotEmpty(t, distributionDomainName)
}

// Helper function to validate CloudFront distribution configuration
func validateDistributionConfiguration(t *testing.T, region, distributionId string, vars map[string]interface{}) {
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
	
	// Validate price class
	if priceClass, ok := vars["price_class"].(string); ok {
		assert.Equal(t, priceClass, *distribution.PriceClass)
	}
	
	// Validate IPv6 setting
	if enableIPv6, ok := vars["enable_ipv6"].(bool); ok {
		assert.Equal(t, enableIPv6, *distribution.IsIPV6Enabled)
	}
	
	// Validate default root object
	if defaultRootObject, ok := vars["default_root_object"].(string); ok {
		assert.Equal(t, defaultRootObject, *distribution.DefaultRootObject)
	}
	
	// Validate distribution is enabled
	assert.True(t, *distribution.Enabled)
	
	// Validate origins
	require.NotEmpty(t, distribution.Origins.Items)
	origin := distribution.Origins.Items[0]
	
	if s3BucketDomain, ok := vars["s3_bucket_domain"].(string); ok {
		assert.Equal(t, s3BucketDomain, *origin.DomainName)
	}
}

// Helper function to validate custom domain configuration
func validateCustomDomainConfiguration(t *testing.T, region, distributionId string, vars map[string]interface{}) {
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
	
	// Validate aliases
	if aliases, ok := vars["aliases"].([]string); ok {
		require.Equal(t, int64(len(aliases)), *distribution.Aliases.Quantity)
		for i, alias := range aliases {
			assert.Equal(t, alias, *distribution.Aliases.Items[i])
		}
	}
	
	// Validate SSL certificate
	if acmCertArn, ok := vars["acm_certificate_arn"].(string); ok {
		require.NotNil(t, distribution.ViewerCertificate)
		require.NotNil(t, distribution.ViewerCertificate.ACMCertificateArn)
		assert.Equal(t, acmCertArn, *distribution.ViewerCertificate.ACMCertificateArn)
		assert.Equal(t, "sni-only", *distribution.ViewerCertificate.SSLSupportMethod)
	}
}

// Helper function to validate security headers
func validateSecurityHeaders(t *testing.T, region, distributionId string) {
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
	
	// Validate default cache behavior exists
	require.NotNil(t, distribution.DefaultCacheBehavior)
	
	// Validate viewer protocol policy (should redirect HTTP to HTTPS)
	assert.Equal(t, "redirect-to-https", *distribution.DefaultCacheBehavior.ViewerProtocolPolicy)
	
	// Validate compression is enabled
	assert.True(t, *distribution.DefaultCacheBehavior.Compress)
}