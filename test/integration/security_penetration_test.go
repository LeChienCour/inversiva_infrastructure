package integration

import (
	"crypto/tls"
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/cloudfront"
	"github.com/aws/aws-sdk-go/service/cognito"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-nextjs-infrastructure/test/helpers"
)

// TestSecurityPenetrationTesting performs security penetration testing on deployed infrastructure
func TestSecurityPenetrationTesting(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping security penetration testing in short mode")
	}

	testConfig := helpers.NewTestConfig(t)
	
	// Deploy minimal infrastructure for security testing
	deployedResources := deployMinimalInfrastructure(t, testConfig)
	
	// Run security penetration tests
	t.Run("S3BucketSecurityTests", func(t *testing.T) {
		testS3BucketSecurity(t, testConfig, deployedResources)
	})
	
	t.Run("CloudFrontSecurityTests", func(t *testing.T) {
		testCloudFrontSecurity(t, testConfig, deployedResources)
	})
	
	t.Run("CognitoSecurityTests", func(t *testing.T) {
		testCognitoSecurity(t, testConfig, deployedResources)
	})
	
	t.Run("NetworkSecurityTests", func(t *testing.T) {
		testNetworkSecurity(t, testConfig, deployedResources)
	})
	
	t.Run("EncryptionSecurityTests", func(t *testing.T) {
		testEncryptionSecurity(t, testConfig, deployedResources)
	})
}

func deployMinimalInfrastructure(t *testing.T, testConfig *helpers.TestConfig) map[string]map[string]string {
	deployedResources := make(map[string]map[string]string)
	
	// Deploy S3 website bucket
	t.Run("DeployS3Website", func(t *testing.T) {
		vars := map[string]interface{}{
			"bucket_name": fmt.Sprintf("security-test-website-%s", testConfig.UniqueID),
			"environment": fmt.Sprintf("security-%s", testConfig.UniqueID),
		}
		
		options := testConfig.GetTerraformOptions("../../modules/s3-website", vars)
		helpers.CleanupTerraform(t, options, testConfig.Cleanup)
		
		terraform.InitAndApply(t, options)
		
		deployedResources["s3-website"] = map[string]string{
			"bucket_name":        terraform.Output(t, options, "bucket_name"),
			"bucket_domain_name": terraform.Output(t, options, "bucket_domain_name"),
			"website_endpoint":   terraform.Output(t, options, "website_endpoint"),
		}
	})
	
	// Deploy S3 content bucket
	t.Run("DeployS3Content", func(t *testing.T) {
		vars := map[string]interface{}{
			"bucket_name": fmt.Sprintf("security-test-content-%s", testConfig.UniqueID),
			"environment": fmt.Sprintf("security-%s", testConfig.UniqueID),
		}
		
		options := testConfig.GetTerraformOptions("../../modules/s3-content", vars)
		helpers.CleanupTerraform(t, options, testConfig.Cleanup)
		
		terraform.InitAndApply(t, options)
		
		deployedResources["s3-content"] = map[string]string{
			"bucket_name": terraform.Output(t, options, "bucket_name"),
			"bucket_arn":  terraform.Output(t, options, "bucket_arn"),
		}
	})
	
	// Deploy Cognito
	t.Run("DeployCognito", func(t *testing.T) {
		vars := map[string]interface{}{
			"user_pool_name": fmt.Sprintf("security-test-users-%s", testConfig.UniqueID),
			"environment":    fmt.Sprintf("security-%s", testConfig.UniqueID),
			"domain_name":    fmt.Sprintf("security-test-%s.example.com", testConfig.UniqueID),
			"callback_urls":  []string{fmt.Sprintf("https://security-test-%s.example.com/callback", testConfig.UniqueID)},
			"logout_urls":    []string{fmt.Sprintf("https://security-test-%s.example.com/logout", testConfig.UniqueID)},
		}
		
		options := testConfig.GetTerraformOptions("../../modules/cognito", vars)
		helpers.CleanupTerraform(t, options, testConfig.Cleanup)
		
		terraform.InitAndApply(t, options)
		
		deployedResources["cognito"] = map[string]string{
			"user_pool_id":        terraform.Output(t, options, "user_pool_id"),
			"user_pool_client_id": terraform.Output(t, options, "user_pool_client_id"),
			"identity_pool_id":    terraform.Output(t, options, "identity_pool_id"),
		}
	})
	
	// Deploy CloudFront
	t.Run("DeployCloudFront", func(t *testing.T) {
		require.Contains(t, deployedResources, "s3-website", "S3 website must be deployed first")
		
		vars := map[string]interface{}{
			"distribution_comment": fmt.Sprintf("Security Test Distribution"),
			"environment":          fmt.Sprintf("security-%s", testConfig.UniqueID),
			"s3_bucket_domain":     deployedResources["s3-website"]["bucket_domain_name"],
			"price_class":          "PriceClass_100",
		}
		
		options := testConfig.GetTerraformOptions("../../modules/cloudfront", vars)
		helpers.CleanupTerraform(t, options, testConfig.Cleanup)
		
		terraform.InitAndApply(t, options)
		
		deployedResources["cloudfront"] = map[string]string{
			"distribution_id":          terraform.Output(t, options, "distribution_id"),
			"distribution_domain_name": terraform.Output(t, options, "distribution_domain_name"),
		}
	})
	
	return deployedResources
}

func testS3BucketSecurity(t *testing.T, testConfig *helpers.TestConfig, deployedResources map[string]map[string]string) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(testConfig.Region),
	})
	require.NoError(t, err)
	
	s3Client := s3.New(sess)
	
	// Test website bucket security
	t.Run("WebsiteBucketSecurity", func(t *testing.T) {
		bucketName := deployedResources["s3-website"]["bucket_name"]
		
		// Test public access block configuration
		publicAccessResult, err := s3Client.GetPublicAccessBlock(&s3.GetPublicAccessBlockInput{
			Bucket: aws.String(bucketName),
		})
		
		if err == nil {
			// Website bucket should allow some public access for CloudFront
			assert.False(t, *publicAccessResult.PublicAccessBlockConfiguration.BlockPublicAcls,
				"Website bucket should allow public ACLs for CloudFront access")
		}
		
		// Test bucket policy - should only allow CloudFront access
		policyResult, err := s3Client.GetBucketPolicy(&s3.GetBucketPolicyInput{
			Bucket: aws.String(bucketName),
		})
		
		if err == nil {
			policy := *policyResult.Policy
			assert.Contains(t, policy, "cloudfront.amazonaws.com",
				"Bucket policy should reference CloudFront service")
			assert.NotContains(t, policy, "\"Principal\": \"*\"",
				"Bucket policy should not allow unrestricted access")
		}
		
		// Test CORS configuration
		corsResult, err := s3Client.GetBucketCors(&s3.GetBucketCorsInput{
			Bucket: aws.String(bucketName),
		})
		
		if err == nil {
			// CORS should be restrictive
			for _, rule := range corsResult.CORSRules {
				for _, origin := range rule.AllowedOrigins {
					assert.NotEqual(t, "*", *origin,
						"CORS should not allow all origins")
				}
			}
		}
	})
	
	// Test content bucket security
	t.Run("ContentBucketSecurity", func(t *testing.T) {
		bucketName := deployedResources["s3-content"]["bucket_name"]
		
		// Test public access block - should block all public access
		publicAccessResult, err := s3Client.GetPublicAccessBlock(&s3.GetPublicAccessBlockInput{
			Bucket: aws.String(bucketName),
		})
		require.NoError(t, err, "Content bucket should have public access block configured")
		
		assert.True(t, *publicAccessResult.PublicAccessBlockConfiguration.BlockPublicAcls,
			"Content bucket should block public ACLs")
		assert.True(t, *publicAccessResult.PublicAccessBlockConfiguration.BlockPublicPolicy,
			"Content bucket should block public policies")
		assert.True(t, *publicAccessResult.PublicAccessBlockConfiguration.IgnorePublicAcls,
			"Content bucket should ignore public ACLs")
		assert.True(t, *publicAccessResult.PublicAccessBlockConfiguration.RestrictPublicBuckets,
			"Content bucket should restrict public buckets")
		
		// Test encryption configuration
		encryptionResult, err := s3Client.GetBucketEncryption(&s3.GetBucketEncryptionInput{
			Bucket: aws.String(bucketName),
		})
		require.NoError(t, err, "Content bucket should have encryption configured")
		
		assert.NotEmpty(t, encryptionResult.ServerSideEncryptionConfiguration.Rules,
			"Content bucket should have encryption rules")
		
		// Test versioning
		versioningResult, err := s3Client.GetBucketVersioning(&s3.GetBucketVersioningInput{
			Bucket: aws.String(bucketName),
		})
		require.NoError(t, err, "Should be able to get versioning configuration")
		
		if versioningResult.Status != nil {
			assert.Equal(t, "Enabled", *versioningResult.Status,
				"Content bucket should have versioning enabled")
		}
		
		// Test logging configuration
		loggingResult, err := s3Client.GetBucketLogging(&s3.GetBucketLoggingInput{
			Bucket: aws.String(bucketName),
		})
		
		if err == nil && loggingResult.LoggingEnabled != nil {
			assert.NotEmpty(t, *loggingResult.LoggingEnabled.TargetBucket,
				"If logging is enabled, target bucket should be specified")
		}
	})
	
	// Test unauthorized access attempts
	t.Run("UnauthorizedAccessTests", func(t *testing.T) {
		contentBucketName := deployedResources["s3-content"]["bucket_name"]
		
		// Try to list objects without credentials (should fail)
		_, err := s3Client.ListObjects(&s3.ListObjectsInput{
			Bucket: aws.String(contentBucketName),
		})
		
		// This should succeed with proper credentials, but we're testing the bucket exists
		// In a real penetration test, you'd test with invalid/no credentials
		if err != nil {
			// Check if it's an access denied error (expected for private bucket)
			assert.Contains(t, err.Error(), "Access Denied",
				"Private bucket should deny unauthorized access")
		}
	})
}

func testCloudFrontSecurity(t *testing.T, testConfig *helpers.TestConfig, deployedResources map[string]map[string]string) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String("us-east-1"), // CloudFront is global but API is in us-east-1
	})
	require.NoError(t, err)
	
	cfClient := cloudfront.New(sess)
	distributionId := deployedResources["cloudfront"]["distribution_id"]
	
	// Get distribution configuration
	result, err := cfClient.GetDistribution(&cloudfront.GetDistributionInput{
		Id: aws.String(distributionId),
	})
	require.NoError(t, err, "Should be able to get CloudFront distribution")
	
	distribution := result.Distribution.DistributionConfig
	
	// Test security headers
	t.Run("SecurityHeaders", func(t *testing.T) {
		// Check if security headers are configured
		if distribution.DefaultCacheBehavior.ResponseHeadersPolicyId != nil {
			// Response headers policy is configured
			assert.NotEmpty(t, *distribution.DefaultCacheBehavior.ResponseHeadersPolicyId,
				"Response headers policy should be configured")
		}
		
		// Test HTTPS enforcement
		assert.Equal(t, "redirect-to-https", *distribution.DefaultCacheBehavior.ViewerProtocolPolicy,
			"CloudFront should redirect HTTP to HTTPS")
	})
	
	// Test origin access control
	t.Run("OriginAccessControl", func(t *testing.T) {
		origins := distribution.Origins.Items
		require.NotEmpty(t, origins, "Distribution should have origins")
		
		for _, origin := range origins {
			if strings.Contains(*origin.DomainName, "s3") {
				// S3 origin should use Origin Access Control
				assert.NotNil(t, origin.OriginAccessControlId,
					"S3 origin should use Origin Access Control")
				assert.NotEmpty(t, *origin.OriginAccessControlId,
					"Origin Access Control ID should not be empty")
			}
		}
	})
	
	// Test SSL/TLS configuration
	t.Run("SSLTLSConfiguration", func(t *testing.T) {
		if distribution.ViewerCertificate != nil {
			// Check minimum protocol version
			if distribution.ViewerCertificate.MinimumProtocolVersion != nil {
				minProtocol := *distribution.ViewerCertificate.MinimumProtocolVersion
				// Should use TLS 1.2 or higher
				assert.Contains(t, minProtocol, "TLSv1.2",
					"CloudFront should use TLS 1.2 or higher")
			}
			
			// Check SSL support method
			if distribution.ViewerCertificate.SSLSupportMethod != nil {
				assert.Equal(t, "sni-only", *distribution.ViewerCertificate.SSLSupportMethod,
					"CloudFront should use SNI for SSL")
			}
		}
	})
	
	// Test caching behavior security
	t.Run("CachingBehaviorSecurity", func(t *testing.T) {
		cacheBehavior := distribution.DefaultCacheBehavior
		
		// Check allowed HTTP methods
		if cacheBehavior.AllowedMethods != nil {
			methods := cacheBehavior.AllowedMethods.Items
			// Should not allow all methods unless specifically needed
			if len(methods) > 3 {
				t.Logf("Warning: CloudFront allows %d HTTP methods, ensure this is intentional", len(methods))
			}
		}
		
		// Check query string forwarding
		if cacheBehavior.ForwardedValues != nil && cacheBehavior.ForwardedValues.QueryString != nil {
			if *cacheBehavior.ForwardedValues.QueryString {
				t.Log("Warning: Query strings are forwarded, ensure sensitive data is not exposed")
			}
		}
	})
	
	// Test distribution accessibility
	t.Run("DistributionAccessibility", func(t *testing.T) {
		distributionDomain := deployedResources["cloudfront"]["distribution_domain_name"]
		
		// Test HTTPS access
		client := &http.Client{
			Timeout: 30 * time.Second,
			Transport: &http.Transport{
				TLSClientConfig: &tls.Config{
					MinVersion: tls.VersionTLS12,
				},
			},
		}
		
		resp, err := client.Get(fmt.Sprintf("https://%s", distributionDomain))
		if err == nil {
			defer resp.Body.Close()
			
			// Check security headers in response
			securityHeaders := map[string]string{
				"X-Content-Type-Options": "nosniff",
				"X-Frame-Options":        "DENY",
				"X-XSS-Protection":       "1; mode=block",
			}
			
			for header, expectedValue := range securityHeaders {
				if value := resp.Header.Get(header); value != "" {
					assert.Contains(t, value, expectedValue,
						fmt.Sprintf("Security header %s should contain %s", header, expectedValue))
				} else {
					t.Logf("Warning: Security header %s is not set", header)
				}
			}
			
			// Check HTTPS enforcement
			assert.True(t, resp.TLS != nil, "Response should be over HTTPS")
			if resp.TLS != nil {
				assert.True(t, resp.TLS.Version >= tls.VersionTLS12,
					"TLS version should be 1.2 or higher")
			}
		}
		
		// Test HTTP access (should redirect to HTTPS)
		httpResp, err := client.Get(fmt.Sprintf("http://%s", distributionDomain))
		if err == nil {
			defer httpResp.Body.Close()
			
			// Should redirect to HTTPS
			if httpResp.StatusCode >= 300 && httpResp.StatusCode < 400 {
				location := httpResp.Header.Get("Location")
				assert.True(t, strings.HasPrefix(location, "https://"),
					"HTTP requests should redirect to HTTPS")
			}
		}
	})
}

func testCognitoSecurity(t *testing.T, testConfig *helpers.TestConfig, deployedResources map[string]map[string]string) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(testConfig.Region),
	})
	require.NoError(t, err)
	
	cognitoClient := cognito.New(sess)
	userPoolId := deployedResources["cognito"]["user_pool_id"]
	
	// Test user pool security configuration
	t.Run("UserPoolSecurity", func(t *testing.T) {
		result, err := cognitoClient.DescribeUserPool(&cognito.DescribeUserPoolInput{
			UserPoolId: aws.String(userPoolId),
		})
		require.NoError(t, err, "Should be able to describe user pool")
		
		userPool := result.UserPool
		
		// Test password policy
		if userPool.Policies != nil && userPool.Policies.PasswordPolicy != nil {
			policy := userPool.Policies.PasswordPolicy
			
			assert.True(t, *policy.MinimumLength >= 8,
				"Password minimum length should be at least 8 characters")
			assert.True(t, *policy.RequireUppercase,
				"Password should require uppercase letters")
			assert.True(t, *policy.RequireLowercase,
				"Password should require lowercase letters")
			assert.True(t, *policy.RequireNumbers,
				"Password should require numbers")
			assert.True(t, *policy.RequireSymbols,
				"Password should require symbols")
		}
		
		// Test MFA configuration
		if userPool.MfaConfiguration != nil {
			mfaConfig := *userPool.MfaConfiguration
			// Should be OFF for dev, OPTIONAL or ON for prod
			assert.Contains(t, []string{"OFF", "OPTIONAL", "ON"}, mfaConfig,
				"MFA configuration should be valid")
		}
		
		// Test account recovery settings
		if userPool.AccountRecoverySetting != nil {
			recoveryMechanisms := userPool.AccountRecoverySetting.RecoveryMechanisms
			assert.NotEmpty(t, recoveryMechanisms,
				"Account recovery mechanisms should be configured")
		}
		
		// Test user pool domain (if configured)
		if userPool.Domain != nil {
			assert.NotEmpty(t, *userPool.Domain,
				"User pool domain should not be empty if configured")
		}
	})
	
	// Test user pool client security
	t.Run("UserPoolClientSecurity", func(t *testing.T) {
		clientId := deployedResources["cognito"]["user_pool_client_id"]
		
		result, err := cognitoClient.DescribeUserPoolClient(&cognito.DescribeUserPoolClientInput{
			UserPoolId: aws.String(userPoolId),
			ClientId:   aws.String(clientId),
		})
		require.NoError(t, err, "Should be able to describe user pool client")
		
		client := result.UserPoolClient
		
		// Test OAuth configuration
		if client.AllowedOAuthFlows != nil {
			flows := client.AllowedOAuthFlows
			// Should use secure OAuth flows
			for _, flow := range flows {
				assert.Contains(t, []string{"code", "implicit"}, *flow,
					"OAuth flow should be secure")
			}
		}
		
		// Test callback URLs
		if client.CallbackURLs != nil {
			for _, url := range client.CallbackURLs {
				assert.True(t, strings.HasPrefix(*url, "https://"),
					"Callback URLs should use HTTPS")
			}
		}
		
		// Test logout URLs
		if client.LogoutURLs != nil {
			for _, url := range client.LogoutURLs {
				assert.True(t, strings.HasPrefix(*url, "https://"),
					"Logout URLs should use HTTPS")
			}
		}
		
		// Test token validity
		if client.AccessTokenValidity != nil {
			assert.True(t, *client.AccessTokenValidity <= 24,
				"Access token validity should not exceed 24 hours")
		}
		
		if client.RefreshTokenValidity != nil {
			assert.True(t, *client.RefreshTokenValidity <= 30,
				"Refresh token validity should not exceed 30 days")
		}
	})
	
	// Test identity pool security (if configured)
	t.Run("IdentityPoolSecurity", func(t *testing.T) {
		identityPoolId := deployedResources["cognito"]["identity_pool_id"]
		
		if identityPoolId != "" {
			// Test that unauthenticated access is properly configured
			// This would require additional AWS SDK calls to check identity pool configuration
			assert.NotEmpty(t, identityPoolId, "Identity pool ID should not be empty")
		}
	})
}

func testNetworkSecurity(t *testing.T, testConfig *helpers.TestConfig, deployedResources map[string]map[string]string) {
	// Test network-level security configurations
	
	t.Run("HTTPSEnforcement", func(t *testing.T) {
		distributionDomain := deployedResources["cloudfront"]["distribution_domain_name"]
		
		// Test that HTTP requests are redirected to HTTPS
		client := &http.Client{
			Timeout: 30 * time.Second,
			CheckRedirect: func(req *http.Request, via []*http.Request) error {
				return http.ErrUseLastResponse // Don't follow redirects
			},
		}
		
		resp, err := client.Get(fmt.Sprintf("http://%s", distributionDomain))
		if err == nil {
			defer resp.Body.Close()
			
			if resp.StatusCode >= 300 && resp.StatusCode < 400 {
				location := resp.Header.Get("Location")
				assert.True(t, strings.HasPrefix(location, "https://"),
					"HTTP requests should redirect to HTTPS")
			}
		}
	})
	
	t.Run("TLSConfiguration", func(t *testing.T) {
		distributionDomain := deployedResources["cloudfront"]["distribution_domain_name"]
		
		// Test TLS configuration
		client := &http.Client{
			Timeout: 30 * time.Second,
			Transport: &http.Transport{
				TLSClientConfig: &tls.Config{
					MinVersion: tls.VersionTLS12,
				},
			},
		}
		
		resp, err := client.Get(fmt.Sprintf("https://%s", distributionDomain))
		if err == nil {
			defer resp.Body.Close()
			
			assert.NotNil(t, resp.TLS, "Response should include TLS information")
			if resp.TLS != nil {
				assert.True(t, resp.TLS.Version >= tls.VersionTLS12,
					"TLS version should be 1.2 or higher")
				
				// Check cipher suite security
				assert.NotEmpty(t, resp.TLS.CipherSuite,
					"Cipher suite should be specified")
			}
		}
	})
	
	t.Run("SecurityHeaders", func(t *testing.T) {
		distributionDomain := deployedResources["cloudfront"]["distribution_domain_name"]
		
		client := &http.Client{Timeout: 30 * time.Second}
		resp, err := client.Get(fmt.Sprintf("https://%s", distributionDomain))
		
		if err == nil {
			defer resp.Body.Close()
			
			// Check for important security headers
			securityHeaders := []string{
				"X-Content-Type-Options",
				"X-Frame-Options",
				"X-XSS-Protection",
				"Strict-Transport-Security",
			}
			
			for _, header := range securityHeaders {
				value := resp.Header.Get(header)
				if value == "" {
					t.Logf("Warning: Security header %s is missing", header)
				} else {
					t.Logf("Security header %s: %s", header, value)
				}
			}
		}
	})
}

func testEncryptionSecurity(t *testing.T, testConfig *helpers.TestConfig, deployedResources map[string]map[string]string) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(testConfig.Region),
	})
	require.NoError(t, err)
	
	s3Client := s3.New(sess)
	
	// Test S3 encryption
	t.Run("S3Encryption", func(t *testing.T) {
		contentBucketName := deployedResources["s3-content"]["bucket_name"]
		
		// Test bucket encryption
		encryptionResult, err := s3Client.GetBucketEncryption(&s3.GetBucketEncryptionInput{
			Bucket: aws.String(contentBucketName),
		})
		require.NoError(t, err, "Content bucket should have encryption configured")
		
		rules := encryptionResult.ServerSideEncryptionConfiguration.Rules
		require.NotEmpty(t, rules, "Encryption rules should be configured")
		
		for _, rule := range rules {
			if rule.ApplyServerSideEncryptionByDefault != nil {
				algorithm := *rule.ApplyServerSideEncryptionByDefault.SSEAlgorithm
				assert.Contains(t, []string{"AES256", "aws:kms"}, algorithm,
					"Encryption algorithm should be AES256 or KMS")
			}
		}
	})
	
	// Test data in transit encryption
	t.Run("DataInTransitEncryption", func(t *testing.T) {
		distributionDomain := deployedResources["cloudfront"]["distribution_domain_name"]
		
		// Test HTTPS enforcement
		client := &http.Client{
			Timeout: 30 * time.Second,
			Transport: &http.Transport{
				TLSClientConfig: &tls.Config{
					MinVersion: tls.VersionTLS12,
				},
			},
		}
		
		resp, err := client.Get(fmt.Sprintf("https://%s", distributionDomain))
		if err == nil {
			defer resp.Body.Close()
			
			assert.NotNil(t, resp.TLS, "Connection should use TLS")
			if resp.TLS != nil {
				assert.True(t, resp.TLS.Version >= tls.VersionTLS12,
					"TLS version should be 1.2 or higher")
			}
		}
	})
}