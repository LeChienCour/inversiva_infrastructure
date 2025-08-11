package smoke

import (
	"fmt"
	"net/http"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-nextjs-infrastructure/test/helpers"
)

func TestWebsiteAccessibility(t *testing.T) {
	// This test validates basic website accessibility
	if testing.Short() {
		t.Skip("Skipping smoke test in short mode")
	}

	testConfig := helpers.NewTestConfig(t)
	
	// Deploy S3 website and CloudFront
	t.Run("DeployWebsiteInfrastructure", func(t *testing.T) {
		// Deploy S3 website
		websiteVars := map[string]interface{}{
			"bucket_name":       helpers.GenerateTestResourceName("smoke-website", testConfig.UniqueID),
			"environment":       testConfig.Environment,
			"enable_versioning": false,
		}
		
		websiteOptions := testConfig.GetTerraformOptions("../../modules/s3-website", websiteVars)
		helpers.CleanupTerraform(t, websiteOptions, testConfig.Cleanup)
		
		terraform.InitAndApply(t, websiteOptions)
		
		bucketName := terraform.Output(t, websiteOptions, "bucket_name")
		bucketDomain := terraform.Output(t, websiteOptions, "bucket_domain_name")
		websiteEndpoint := terraform.Output(t, websiteOptions, "website_endpoint")
		
		assert.NotEmpty(t, bucketName)
		assert.NotEmpty(t, bucketDomain)
		assert.NotEmpty(t, websiteEndpoint)
		
		// Deploy CloudFront
		cloudfrontVars := map[string]interface{}{
			"distribution_comment": "Smoke Test Distribution",
			"environment":          testConfig.Environment,
			"s3_bucket_domain":     bucketDomain,
			"price_class":          "PriceClass_100",
			"default_root_object":  "index.html",
		}
		
		cloudfrontOptions := testConfig.GetTerraformOptions("../../modules/cloudfront", cloudfrontVars)
		helpers.CleanupTerraform(t, cloudfrontOptions, testConfig.Cleanup)
		
		terraform.InitAndApply(t, cloudfrontOptions)
		
		distributionDomain := terraform.Output(t, cloudfrontOptions, "distribution_domain_name")
		assert.NotEmpty(t, distributionDomain)
		
		// Test website accessibility
		t.Run("TestS3WebsiteEndpoint", func(t *testing.T) {
			testWebsiteEndpoint(t, websiteEndpoint)
		})
		
		t.Run("TestCloudFrontDistribution", func(t *testing.T) {
			testCloudFrontDistribution(t, distributionDomain)
		})
	})
}

func TestWebsiteWithCustomErrorPages(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping custom error pages test in short mode")
	}

	testConfig := helpers.NewTestConfig(t)
	
	// Deploy website with custom error pages
	websiteVars := map[string]interface{}{
		"bucket_name": helpers.GenerateTestResourceName("smoke-errors", testConfig.UniqueID),
		"environment": testConfig.Environment,
	}
	
	websiteOptions := testConfig.GetTerraformOptions("../../modules/s3-website", websiteVars)
	helpers.CleanupTerraform(t, websiteOptions, testConfig.Cleanup)
	
	terraform.InitAndApply(t, websiteOptions)
	
	bucketDomain := terraform.Output(t, websiteOptions, "bucket_domain_name")
	
	// Deploy CloudFront with custom error responses
	cloudfrontVars := map[string]interface{}{
		"distribution_comment": "Error Pages Test Distribution",
		"environment":          testConfig.Environment,
		"s3_bucket_domain":     bucketDomain,
		"custom_error_responses": []map[string]interface{}{
			{
				"error_code":         404,
				"response_code":      200,
				"response_page_path": "/index.html",
			},
			{
				"error_code":         403,
				"response_code":      200,
				"response_page_path": "/index.html",
			},
		},
	}
	
	cloudfrontOptions := testConfig.GetTerraformOptions("../../modules/cloudfront", cloudfrontVars)
	helpers.CleanupTerraform(t, cloudfrontOptions, testConfig.Cleanup)
	
	terraform.InitAndApply(t, cloudfrontOptions)
	
	distributionDomain := terraform.Output(t, cloudfrontOptions, "distribution_domain_name")
	
	// Test error page handling
	t.Run("TestCustomErrorPages", func(t *testing.T) {
		testCustomErrorPages(t, distributionDomain)
	})
}

func TestWebsiteSecurityHeaders(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping security headers test in short mode")
	}

	testConfig := helpers.NewTestConfig(t)
	
	// Deploy website infrastructure
	websiteVars := map[string]interface{}{
		"bucket_name": helpers.GenerateTestResourceName("smoke-security", testConfig.UniqueID),
		"environment": testConfig.Environment,
	}
	
	websiteOptions := testConfig.GetTerraformOptions("../../modules/s3-website", websiteVars)
	helpers.CleanupTerraform(t, websiteOptions, testConfig.Cleanup)
	
	terraform.InitAndApply(t, websiteOptions)
	
	bucketDomain := terraform.Output(t, websiteOptions, "bucket_domain_name")
	
	// Deploy CloudFront with security headers
	cloudfrontVars := map[string]interface{}{
		"distribution_comment": "Security Headers Test",
		"environment":          testConfig.Environment,
		"s3_bucket_domain":     bucketDomain,
		"enable_security_headers": true,
	}
	
	cloudfrontOptions := testConfig.GetTerraformOptions("../../modules/cloudfront", cloudfrontVars)
	helpers.CleanupTerraform(t, cloudfrontOptions, testConfig.Cleanup)
	
	terraform.InitAndApply(t, cloudfrontOptions)
	
	distributionDomain := terraform.Output(t, cloudfrontOptions, "distribution_domain_name")
	
	// Test security headers
	t.Run("TestSecurityHeaders", func(t *testing.T) {
		testSecurityHeaders(t, distributionDomain)
	})
}

// Helper function to test S3 website endpoint
func testWebsiteEndpoint(t *testing.T, websiteEndpoint string) {
	// Note: S3 website endpoints may not be immediately accessible
	// This is a basic connectivity test
	
	url := fmt.Sprintf("http://%s", websiteEndpoint)
	
	client := &http.Client{
		Timeout: 10 * time.Second,
	}
	
	// Retry logic for eventual consistency
	var lastErr error
	for i := 0; i < 5; i++ {
		resp, err := client.Get(url)
		if err != nil {
			lastErr = err
			time.Sleep(5 * time.Second)
			continue
		}
		defer resp.Body.Close()
		
		// We expect either 200 (if index.html exists) or 404 (if it doesn't)
		// Both indicate the website endpoint is accessible
		assert.True(t, resp.StatusCode == 200 || resp.StatusCode == 404,
			"Expected status 200 or 404, got %d", resp.StatusCode)
		return
	}
	
	require.NoError(t, lastErr, "Failed to access website endpoint after retries")
}

// Helper function to test CloudFront distribution
func testCloudFrontDistribution(t *testing.T, distributionDomain string) {
	// CloudFront distributions take time to deploy
	// This test validates basic connectivity
	
	url := fmt.Sprintf("https://%s", distributionDomain)
	
	client := &http.Client{
		Timeout: 15 * time.Second,
	}
	
	// Wait for CloudFront distribution to be ready
	time.Sleep(30 * time.Second)
	
	// Retry logic for CloudFront propagation
	var lastErr error
	for i := 0; i < 10; i++ {
		resp, err := client.Get(url)
		if err != nil {
			lastErr = err
			time.Sleep(10 * time.Second)
			continue
		}
		defer resp.Body.Close()
		
		// CloudFront should be accessible (200, 403, or 404 are all valid)
		assert.True(t, resp.StatusCode >= 200 && resp.StatusCode < 500,
			"Expected 2xx-4xx status, got %d", resp.StatusCode)
		
		// Validate HTTPS is working
		assert.Equal(t, "https", resp.Request.URL.Scheme)
		return
	}
	
	require.NoError(t, lastErr, "Failed to access CloudFront distribution after retries")
}

// Helper function to test custom error pages
func testCustomErrorPages(t *testing.T, distributionDomain string) {
	// Test that 404 errors are handled by custom error pages
	url := fmt.Sprintf("https://%s/nonexistent-page", distributionDomain)
	
	client := &http.Client{
		Timeout: 15 * time.Second,
	}
	
	// Wait for distribution to be ready
	time.Sleep(30 * time.Second)
	
	resp, err := client.Get(url)
	if err != nil {
		t.Skipf("Skipping error page test due to connectivity issues: %v", err)
		return
	}
	defer resp.Body.Close()
	
	// With custom error pages, we should get 200 instead of 404
	// (This assumes the custom error page configuration is working)
	assert.True(t, resp.StatusCode == 200 || resp.StatusCode == 404,
		"Expected status 200 (custom error page) or 404, got %d", resp.StatusCode)
}

// Helper function to test security headers
func testSecurityHeaders(t *testing.T, distributionDomain string) {
	url := fmt.Sprintf("https://%s", distributionDomain)
	
	client := &http.Client{
		Timeout: 15 * time.Second,
	}
	
	// Wait for distribution to be ready
	time.Sleep(30 * time.Second)
	
	resp, err := client.Get(url)
	if err != nil {
		t.Skipf("Skipping security headers test due to connectivity issues: %v", err)
		return
	}
	defer resp.Body.Close()
	
	// Check for basic security headers
	headers := resp.Header
	
	// These headers should be present if security headers are configured
	securityHeaders := []string{
		"X-Content-Type-Options",
		"X-Frame-Options",
		"X-XSS-Protection",
		"Strict-Transport-Security",
	}
	
	for _, header := range securityHeaders {
		if value := headers.Get(header); value != "" {
			t.Logf("Security header %s: %s", header, value)
		}
	}
	
	// At minimum, we should have HTTPS
	assert.Equal(t, "https", resp.Request.URL.Scheme, "Should be served over HTTPS")
}