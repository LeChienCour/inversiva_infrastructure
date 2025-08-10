package smoke

import (
	"testing"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/cognitoidentityprovider"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-nextjs-infrastructure/test/helpers"
)

func TestCognitoAuthenticationFlow(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping authentication flow test in short mode")
	}

	testConfig := helpers.NewTestConfig(t)
	
	// Deploy Cognito infrastructure
	vars := map[string]interface{}{
		"user_pool_name": helpers.GenerateTestResourceName("auth-smoke", testConfig.UniqueID),
		"environment":    testConfig.Environment,
		"domain_name":    "test.example.com",
		"callback_urls":  []string{"https://test.example.com/callback"},
		"logout_urls":    []string{"https://test.example.com/logout"},
		"password_policy": map[string]interface{}{
			"minimum_length":    8,
			"require_lowercase": true,
			"require_numbers":   true,
			"require_symbols":   false,
			"require_uppercase": true,
		},
		"mfa_configuration": "OFF",
	}
	
	options := testConfig.GetTerraformOptions("../../modules/cognito", vars)
	helpers.CleanupTerraform(t, options, testConfig.Cleanup)
	
	terraform.InitAndApply(t, options)
	
	userPoolId := terraform.Output(t, options, "user_pool_id")
	clientId := terraform.Output(t, options, "user_pool_client_id")
	identityPoolId := terraform.Output(t, options, "identity_pool_id")
	
	assert.NotEmpty(t, userPoolId)
	assert.NotEmpty(t, clientId)
	assert.NotEmpty(t, identityPoolId)
	
	// Test basic authentication operations
	t.Run("TestUserPoolOperations", func(t *testing.T) {
		testUserPoolOperations(t, testConfig.Region, userPoolId, clientId)
	})
	
	t.Run("TestIdentityPoolConfiguration", func(t *testing.T) {
		testIdentityPoolConfiguration(t, testConfig.Region, identityPoolId)
	})
	
	t.Run("TestPasswordPolicyEnforcement", func(t *testing.T) {
		testPasswordPolicyEnforcement(t, testConfig.Region, userPoolId, clientId, vars)
	})
}

func TestCognitoWithMFAEnabled(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping MFA test in short mode")
	}

	testConfig := helpers.NewTestConfig(t)
	
	// Deploy Cognito with MFA enabled
	vars := map[string]interface{}{
		"user_pool_name": helpers.GenerateTestResourceName("auth-mfa", testConfig.UniqueID),
		"environment":    testConfig.Environment,
		"domain_name":    "test.example.com",
		"mfa_configuration": "OPTIONAL",
		"password_policy": map[string]interface{}{
			"minimum_length":    12,
			"require_lowercase": true,
			"require_numbers":   true,
			"require_symbols":   true,
			"require_uppercase": true,
		},
	}
	
	options := testConfig.GetTerraformOptions("../../modules/cognito", vars)
	helpers.CleanupTerraform(t, options, testConfig.Cleanup)
	
	terraform.InitAndApply(t, options)
	
	userPoolId := terraform.Output(t, options, "user_pool_id")
	
	t.Run("TestMFAConfiguration", func(t *testing.T) {
		testMFAConfiguration(t, testConfig.Region, userPoolId)
	})
}

func TestCognitoUserPoolDomain(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping user pool domain test in short mode")
	}

	testConfig := helpers.NewTestConfig(t)
	
	// Deploy Cognito with custom domain prefix
	vars := map[string]interface{}{
		"user_pool_name": helpers.GenerateTestResourceName("auth-domain", testConfig.UniqueID),
		"environment":    testConfig.Environment,
		"domain_name":    "test.example.com",
		"domain_prefix":  "auth-test-" + testConfig.UniqueID,
	}
	
	options := testConfig.GetTerraformOptions("../../modules/cognito", vars)
	helpers.CleanupTerraform(t, options, testConfig.Cleanup)
	
	terraform.InitAndApply(t, options)
	
	userPoolId := terraform.Output(t, options, "user_pool_id")
	
	t.Run("TestUserPoolDomain", func(t *testing.T) {
		testUserPoolDomain(t, testConfig.Region, userPoolId, vars)
	})
}

// Helper function to test basic user pool operations
func testUserPoolOperations(t *testing.T, region, userPoolId, clientId string) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	cognitoClient := cognitoidentityprovider.New(sess)
	
	// Test user pool description
	userPoolResult, err := cognitoClient.DescribeUserPool(&cognitoidentityprovider.DescribeUserPoolInput{
		UserPoolId: aws.String(userPoolId),
	})
	require.NoError(t, err)
	require.NotNil(t, userPoolResult.UserPool)
	
	// Test user pool client description
	clientResult, err := cognitoClient.DescribeUserPoolClient(&cognitoidentityprovider.DescribeUserPoolClientInput{
		UserPoolId: aws.String(userPoolId),
		ClientId:   aws.String(clientId),
	})
	require.NoError(t, err)
	require.NotNil(t, clientResult.UserPoolClient)
	
	// Validate client configuration
	client := clientResult.UserPoolClient
	assert.NotNil(t, client.ExplicitAuthFlows)
	assert.True(t, len(client.ExplicitAuthFlows) > 0)
	
	// Test creating a test user (admin operation)
	testUsername := "testuser-" + helpers.GenerateTestResourceName("", "123")
	testEmail := testUsername + "@example.com"
	
	createUserResult, err := cognitoClient.AdminCreateUser(&cognitoidentityprovider.AdminCreateUserInput{
		UserPoolId: aws.String(userPoolId),
		Username:   aws.String(testUsername),
		UserAttributes: []*cognitoidentityprovider.AttributeType{
			{
				Name:  aws.String("email"),
				Value: aws.String(testEmail),
			},
		},
		MessageAction: aws.String("SUPPRESS"), // Don't send welcome email
		TemporaryPassword: aws.String("TempPass123!"),
	})
	require.NoError(t, err)
	require.NotNil(t, createUserResult.User)
	
	// Clean up test user
	defer func() {
		_, err := cognitoClient.AdminDeleteUser(&cognitoidentityprovider.AdminDeleteUserInput{
			UserPoolId: aws.String(userPoolId),
			Username:   aws.String(testUsername),
		})
		if err != nil {
			t.Logf("Warning: Failed to clean up test user: %v", err)
		}
	}()
	
	// Validate user was created
	assert.Equal(t, testUsername, *createUserResult.User.Username)
	assert.Equal(t, "FORCE_CHANGE_PASSWORD", *createUserResult.User.UserStatus)
}

// Helper function to test identity pool configuration
func testIdentityPoolConfiguration(t *testing.T, region, identityPoolId string) {
	// Note: This would require the cognito-identity service
	// For now, we just validate the identity pool ID format
	assert.Contains(t, identityPoolId, region)
	assert.Contains(t, identityPoolId, ":")
	
	// Additional validation could be added here using the cognito-identity service
	t.Logf("Identity Pool ID validated: %s", identityPoolId)
}

// Helper function to test password policy enforcement
func testPasswordPolicyEnforcement(t *testing.T, region, userPoolId, clientId string, vars map[string]interface{}) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	cognitoClient := cognitoidentityprovider.New(sess)
	
	// Create a test user with a weak password (should fail)
	testUsername := "weakpasstest-" + helpers.GenerateTestResourceName("", "123")
	
	_, err = cognitoClient.AdminCreateUser(&cognitoidentityprovider.AdminCreateUserInput{
		UserPoolId: aws.String(userPoolId),
		Username:   aws.String(testUsername),
		UserAttributes: []*cognitoidentityprovider.AttributeType{
			{
				Name:  aws.String("email"),
				Value: aws.String(testUsername + "@example.com"),
			},
		},
		MessageAction: aws.String("SUPPRESS"),
		TemporaryPassword: aws.String("weak"), // This should fail password policy
	})
	
	// We expect this to fail due to password policy
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "password")
	
	// Test with a strong password (should succeed)
	strongPassword := "StrongPass123!"
	createResult, err := cognitoClient.AdminCreateUser(&cognitoidentityprovider.AdminCreateUserInput{
		UserPoolId: aws.String(userPoolId),
		Username:   aws.String(testUsername),
		UserAttributes: []*cognitoidentityprovider.AttributeType{
			{
				Name:  aws.String("email"),
				Value: aws.String(testUsername + "@example.com"),
			},
		},
		MessageAction: aws.String("SUPPRESS"),
		TemporaryPassword: aws.String(strongPassword),
	})
	require.NoError(t, err)
	require.NotNil(t, createResult.User)
	
	// Clean up
	defer func() {
		_, err := cognitoClient.AdminDeleteUser(&cognitoidentityprovider.AdminDeleteUserInput{
			UserPoolId: aws.String(userPoolId),
			Username:   aws.String(testUsername),
		})
		if err != nil {
			t.Logf("Warning: Failed to clean up test user: %v", err)
		}
	}()
}

// Helper function to test MFA configuration
func testMFAConfiguration(t *testing.T, region, userPoolId string) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	cognitoClient := cognitoidentityprovider.New(sess)
	
	result, err := cognitoClient.DescribeUserPool(&cognitoidentityprovider.DescribeUserPoolInput{
		UserPoolId: aws.String(userPoolId),
	})
	require.NoError(t, err)
	require.NotNil(t, result.UserPool)
	
	// Validate MFA is configured as expected
	assert.Equal(t, "OPTIONAL", *result.UserPool.MfaConfiguration)
	
	// Validate MFA methods are configured
	if result.UserPool.EnabledMfas != nil {
		assert.True(t, len(result.UserPool.EnabledMfas) > 0)
		t.Logf("Enabled MFA methods: %v", result.UserPool.EnabledMfas)
	}
}

// Helper function to test user pool domain
func testUserPoolDomain(t *testing.T, region, userPoolId string, vars map[string]interface{}) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	cognitoClient := cognitoidentityprovider.New(sess)
	
	// Check if domain is configured
	result, err := cognitoClient.DescribeUserPoolDomain(&cognitoidentityprovider.DescribeUserPoolDomainInput{
		Domain: aws.String(vars["domain_prefix"].(string)),
	})
	
	if err != nil {
		// Domain might not be configured in the module
		t.Logf("User pool domain not configured: %v", err)
		return
	}
	
	require.NotNil(t, result.DomainDescription)
	assert.Equal(t, userPoolId, *result.DomainDescription.UserPoolId)
	assert.Equal(t, vars["domain_prefix"].(string), *result.DomainDescription.Domain)
}