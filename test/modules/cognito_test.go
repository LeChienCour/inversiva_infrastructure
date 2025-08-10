package modules

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

func TestCognitoModule(t *testing.T) {
	t.Parallel()

	// Setup test configuration
	testConfig := helpers.NewTestConfig(t)
	
	// Define test variables
	vars := map[string]interface{}{
		"user_pool_name": helpers.GenerateTestResourceName("userpool", testConfig.UniqueID),
		"environment":    testConfig.Environment,
		"domain_name":    "example.com",
		"callback_urls":  []string{"https://example.com/callback"},
		"logout_urls":    []string{"https://example.com/logout"},
		"password_policy": map[string]interface{}{
			"minimum_length":    8,
			"require_lowercase": true,
			"require_numbers":   true,
			"require_symbols":   false,
			"require_uppercase": true,
		},
		"mfa_configuration": "OFF",
		"tags": map[string]string{
			"Environment": testConfig.Environment,
			"Testing":     "true",
		},
	}

	// Configure Terraform options
	terraformOptions := testConfig.GetTerraformOptions("../../modules/cognito", vars)
	
	// Cleanup resources after test
	helpers.CleanupTerraform(t, terraformOptions, testConfig.Cleanup)

	// Run terraform init and apply
	terraform.InitAndApply(t, terraformOptions)

	// Validate outputs
	userPoolId := terraform.Output(t, terraformOptions, "user_pool_id")
	userPoolClientId := terraform.Output(t, terraformOptions, "user_pool_client_id")
	identityPoolId := terraform.Output(t, terraformOptions, "identity_pool_id")
	userPoolArn := terraform.Output(t, terraformOptions, "user_pool_arn")

	// Assertions
	assert.NotEmpty(t, userPoolId)
	assert.NotEmpty(t, userPoolClientId)
	assert.NotEmpty(t, identityPoolId)
	assert.NotEmpty(t, userPoolArn)
	assert.Contains(t, userPoolArn, userPoolId)

	// Validate Cognito User Pool configuration
	t.Run("ValidateUserPoolConfiguration", func(t *testing.T) {
		validateUserPoolConfiguration(t, testConfig.Region, userPoolId, vars)
	})

	t.Run("ValidateUserPoolClient", func(t *testing.T) {
		validateUserPoolClient(t, testConfig.Region, userPoolId, userPoolClientId, vars)
	})
}

func TestCognitoModuleWithMFA(t *testing.T) {
	t.Parallel()

	// Setup test configuration
	testConfig := helpers.NewTestConfig(t)
	
	// Define test variables with MFA enabled
	vars := map[string]interface{}{
		"user_pool_name": helpers.GenerateTestResourceName("userpool-mfa", testConfig.UniqueID),
		"environment":    testConfig.Environment,
		"domain_name":    "example.com",
		"callback_urls":  []string{"https://example.com/callback"},
		"logout_urls":    []string{"https://example.com/logout"},
		"password_policy": map[string]interface{}{
			"minimum_length":    12,
			"require_lowercase": true,
			"require_numbers":   true,
			"require_symbols":   true,
			"require_uppercase": true,
		},
		"mfa_configuration": "OPTIONAL",
		"tags": map[string]string{
			"Environment": testConfig.Environment,
			"Testing":     "true",
		},
	}

	// Configure Terraform options
	terraformOptions := testConfig.GetTerraformOptions("../../modules/cognito", vars)
	
	// Cleanup resources after test
	helpers.CleanupTerraform(t, terraformOptions, testConfig.Cleanup)

	// Run terraform init and apply
	terraform.InitAndApply(t, terraformOptions)

	// Validate MFA configuration
	userPoolId := terraform.Output(t, terraformOptions, "user_pool_id")
	
	t.Run("ValidateMFAConfiguration", func(t *testing.T) {
		validateMFAConfiguration(t, testConfig.Region, userPoolId, "OPTIONAL")
	})
}

func TestCognitoModuleMinimalConfig(t *testing.T) {
	t.Parallel()

	// Setup test configuration
	testConfig := helpers.NewTestConfig(t)
	
	// Define minimal test variables
	vars := map[string]interface{}{
		"user_pool_name": helpers.GenerateTestResourceName("userpool-minimal", testConfig.UniqueID),
		"environment":    testConfig.Environment,
		"domain_name":    "example.com",
	}

	// Configure Terraform options
	terraformOptions := testConfig.GetTerraformOptions("../../modules/cognito", vars)
	
	// Cleanup resources after test
	helpers.CleanupTerraform(t, terraformOptions, testConfig.Cleanup)

	// Run terraform init and apply
	terraform.InitAndApply(t, terraformOptions)

	// Validate basic outputs exist
	userPoolId := terraform.Output(t, terraformOptions, "user_pool_id")
	userPoolClientId := terraform.Output(t, terraformOptions, "user_pool_client_id")

	assert.NotEmpty(t, userPoolId)
	assert.NotEmpty(t, userPoolClientId)
}

// Helper function to validate User Pool configuration
func validateUserPoolConfiguration(t *testing.T, region, userPoolId string, vars map[string]interface{}) {
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
	
	userPool := result.UserPool
	
	// Validate password policy
	if passwordPolicy, ok := vars["password_policy"].(map[string]interface{}); ok {
		require.NotNil(t, userPool.Policies)
		require.NotNil(t, userPool.Policies.PasswordPolicy)
		
		policy := userPool.Policies.PasswordPolicy
		assert.Equal(t, int64(passwordPolicy["minimum_length"].(int)), *policy.MinimumLength)
		assert.Equal(t, passwordPolicy["require_lowercase"].(bool), *policy.RequireLowercase)
		assert.Equal(t, passwordPolicy["require_numbers"].(bool), *policy.RequireNumbers)
		assert.Equal(t, passwordPolicy["require_symbols"].(bool), *policy.RequireSymbols)
		assert.Equal(t, passwordPolicy["require_uppercase"].(bool), *policy.RequireUppercase)
	}
	
	// Validate MFA configuration
	if mfaConfig, ok := vars["mfa_configuration"].(string); ok {
		assert.Equal(t, mfaConfig, *userPool.MfaConfiguration)
	}
}

// Helper function to validate User Pool Client configuration
func validateUserPoolClient(t *testing.T, region, userPoolId, clientId string, vars map[string]interface{}) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	cognitoClient := cognitoidentityprovider.New(sess)
	
	result, err := cognitoClient.DescribeUserPoolClient(&cognitoidentityprovider.DescribeUserPoolClientInput{
		UserPoolId: aws.String(userPoolId),
		ClientId:   aws.String(clientId),
	})
	require.NoError(t, err)
	require.NotNil(t, result.UserPoolClient)
	
	client := result.UserPoolClient
	
	// Validate callback URLs
	if callbackUrls, ok := vars["callback_urls"].([]string); ok {
		require.Equal(t, len(callbackUrls), len(client.CallbackURLs))
		for i, url := range callbackUrls {
			assert.Equal(t, url, *client.CallbackURLs[i])
		}
	}
	
	// Validate logout URLs
	if logoutUrls, ok := vars["logout_urls"].([]string); ok {
		require.Equal(t, len(logoutUrls), len(client.LogoutURLs))
		for i, url := range logoutUrls {
			assert.Equal(t, url, *client.LogoutURLs[i])
		}
	}
}

// Helper function to validate MFA configuration
func validateMFAConfiguration(t *testing.T, region, userPoolId, expectedMFA string) {
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
	
	assert.Equal(t, expectedMFA, *result.UserPool.MfaConfiguration)
}