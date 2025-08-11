package security

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

func TestCognitoSecurityConfiguration(t *testing.T) {
	t.Parallel()

	testConfig := helpers.NewTestConfig(t)
	
	// Deploy Cognito with security-focused configuration
	vars := map[string]interface{}{
		"user_pool_name": helpers.GenerateTestResourceName("security-cognito", testConfig.UniqueID),
		"environment":    testConfig.Environment,
		"domain_name":    "secure.example.com",
		"callback_urls":  []string{"https://secure.example.com/callback"},
		"logout_urls":    []string{"https://secure.example.com/logout"},
		"password_policy": map[string]interface{}{
			"minimum_length":    12,
			"require_lowercase": true,
			"require_numbers":   true,
			"require_symbols":   true,
			"require_uppercase": true,
		},
		"mfa_configuration": "OPTIONAL",
	}
	
	options := testConfig.GetTerraformOptions("../../modules/cognito", vars)
	helpers.CleanupTerraform(t, options, testConfig.Cleanup)
	
	terraform.InitAndApply(t, options)
	
	userPoolId := terraform.Output(t, options, "user_pool_id")
	clientId := terraform.Output(t, options, "user_pool_client_id")
	
	t.Run("ValidatePasswordPolicy", func(t *testing.T) {
		validateCognitoPasswordPolicy(t, testConfig.Region, userPoolId, vars)
	})
	
	t.Run("ValidateMFAConfiguration", func(t *testing.T) {
		validateCognitoMFAConfiguration(t, testConfig.Region, userPoolId)
	})
	
	t.Run("ValidateUserPoolClientSecurity", func(t *testing.T) {
		validateCognitoClientSecurity(t, testConfig.Region, userPoolId, clientId)
	})
	
	t.Run("ValidateUserPoolSecurity", func(t *testing.T) {
		validateCognitoUserPoolSecurity(t, testConfig.Region, userPoolId)
	})
	
	t.Run("ValidateAccountRecovery", func(t *testing.T) {
		validateCognitoAccountRecovery(t, testConfig.Region, userPoolId)
	})
}

func TestCognitoProductionSecuritySettings(t *testing.T) {
	t.Parallel()

	testConfig := helpers.NewTestConfig(t)
	
	// Deploy Cognito with production-grade security settings
	vars := map[string]interface{}{
		"user_pool_name": helpers.GenerateTestResourceName("prod-security", testConfig.UniqueID),
		"environment":    "prod",
		"domain_name":    "prod.example.com",
		"password_policy": map[string]interface{}{
			"minimum_length":    16,
			"require_lowercase": true,
			"require_numbers":   true,
			"require_symbols":   true,
			"require_uppercase": true,
		},
		"mfa_configuration": "ON", // Required for production
		"account_recovery_setting": map[string]interface{}{
			"recovery_mechanisms": []map[string]interface{}{
				{
					"name":     "verified_email",
					"priority": 1,
				},
			},
		},
	}
	
	options := testConfig.GetTerraformOptions("../../modules/cognito", vars)
	helpers.CleanupTerraform(t, options, testConfig.Cleanup)
	
	terraform.InitAndApply(t, options)
	
	userPoolId := terraform.Output(t, options, "user_pool_id")
	
	t.Run("ValidateProductionPasswordPolicy", func(t *testing.T) {
		validateCognitoPasswordPolicy(t, testConfig.Region, userPoolId, vars)
	})
	
	t.Run("ValidateRequiredMFA", func(t *testing.T) {
		validateCognitoRequiredMFA(t, testConfig.Region, userPoolId)
	})
	
	t.Run("ValidateAccountRecoverySettings", func(t *testing.T) {
		validateCognitoAccountRecovery(t, testConfig.Region, userPoolId)
	})
}

func TestCognitoSecurityCompliance(t *testing.T) {
	t.Parallel()

	testConfig := helpers.NewTestConfig(t)
	
	// Test compliance with security best practices
	vars := map[string]interface{}{
		"user_pool_name": helpers.GenerateTestResourceName("compliance", testConfig.UniqueID),
		"environment":    testConfig.Environment,
		"domain_name":    "compliance.example.com",
		"password_policy": map[string]interface{}{
			"minimum_length":    14,
			"require_lowercase": true,
			"require_numbers":   true,
			"require_symbols":   true,
			"require_uppercase": true,
		},
		"mfa_configuration": "OPTIONAL",
	}
	
	options := testConfig.GetTerraformOptions("../../modules/cognito", vars)
	helpers.CleanupTerraform(t, options, testConfig.Cleanup)
	
	terraform.InitAndApply(t, options)
	
	userPoolId := terraform.Output(t, options, "user_pool_id")
	clientId := terraform.Output(t, options, "user_pool_client_id")
	
	t.Run("ComplianceChecks", func(t *testing.T) {
		validateCognitoComplianceChecks(t, testConfig.Region, userPoolId, clientId)
	})
}

// Helper function to validate Cognito password policy
func validateCognitoPasswordPolicy(t *testing.T, region, userPoolId string, vars map[string]interface{}) {
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
	require.NotNil(t, result.UserPool.Policies)
	require.NotNil(t, result.UserPool.Policies.PasswordPolicy)
	
	policy := result.UserPool.Policies.PasswordPolicy
	expectedPolicy := vars["password_policy"].(map[string]interface{})
	
	// Validate password policy settings
	assert.Equal(t, int64(expectedPolicy["minimum_length"].(int)), *policy.MinimumLength)
	assert.Equal(t, expectedPolicy["require_lowercase"].(bool), *policy.RequireLowercase)
	assert.Equal(t, expectedPolicy["require_numbers"].(bool), *policy.RequireNumbers)
	assert.Equal(t, expectedPolicy["require_symbols"].(bool), *policy.RequireSymbols)
	assert.Equal(t, expectedPolicy["require_uppercase"].(bool), *policy.RequireUppercase)
	
	// Security best practices validation
	assert.True(t, *policy.MinimumLength >= 8, "Password minimum length should be at least 8")
	assert.True(t, *policy.RequireLowercase, "Password should require lowercase letters")
	assert.True(t, *policy.RequireNumbers, "Password should require numbers")
	assert.True(t, *policy.RequireUppercase, "Password should require uppercase letters")
	
	// For production environments, enforce stronger requirements
	if vars["environment"] == "prod" {
		assert.True(t, *policy.MinimumLength >= 12, "Production password minimum length should be at least 12")
		assert.True(t, *policy.RequireSymbols, "Production passwords should require symbols")
	}
	
	t.Logf("Password policy validation passed for user pool %s", userPoolId)
}

// Helper function to validate MFA configuration
func validateCognitoMFAConfiguration(t *testing.T, region, userPoolId string) {
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
	
	mfaConfig := *result.UserPool.MfaConfiguration
	assert.True(t, mfaConfig == "OPTIONAL" || mfaConfig == "ON",
		"MFA should be OPTIONAL or ON, got %s", mfaConfig)
	
	// Validate MFA methods are configured
	if result.UserPool.EnabledMfas != nil && len(result.UserPool.EnabledMfas) > 0 {
		t.Logf("MFA methods enabled: %v", result.UserPool.EnabledMfas)
		
		// Validate at least one secure MFA method is enabled
		hasSecureMFA := false
		for _, mfa := range result.UserPool.EnabledMfas {
			if *mfa == "SOFTWARE_TOKEN_MFA" || *mfa == "SMS_MFA" {
				hasSecureMFA = true
				break
			}
		}
		assert.True(t, hasSecureMFA, "At least one secure MFA method should be enabled")
	}
	
	t.Logf("MFA configuration validated for user pool %s: %s", userPoolId, mfaConfig)
}

// Helper function to validate required MFA for production
func validateCognitoRequiredMFA(t *testing.T, region, userPoolId string) {
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
	
	// Production environments should have MFA required
	assert.Equal(t, "ON", *result.UserPool.MfaConfiguration,
		"Production user pools should have MFA required")
	
	t.Logf("Required MFA validated for production user pool %s", userPoolId)
}

// Helper function to validate user pool client security
func validateCognitoClientSecurity(t *testing.T, region, userPoolId, clientId string) {
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
	
	// Validate secure authentication flows are enabled
	require.NotNil(t, client.ExplicitAuthFlows)
	assert.True(t, len(client.ExplicitAuthFlows) > 0, "At least one auth flow should be enabled")
	
	// Check for secure auth flows
	hasSecureFlow := false
	for _, flow := range client.ExplicitAuthFlows {
		if *flow == "ALLOW_USER_SRP_AUTH" || *flow == "ALLOW_USER_PASSWORD_AUTH" {
			hasSecureFlow = true
			break
		}
	}
	assert.True(t, hasSecureFlow, "At least one secure auth flow should be enabled")
	
	// Validate token validity periods are reasonable
	if client.AccessTokenValidity != nil {
		assert.True(t, *client.AccessTokenValidity <= 24, // 24 hours max
			"Access token validity should not exceed 24 hours")
	}
	
	if client.RefreshTokenValidity != nil {
		assert.True(t, *client.RefreshTokenValidity <= 30, // 30 days max
			"Refresh token validity should not exceed 30 days")
	}
	
	t.Logf("User pool client security validated for %s", clientId)
}

// Helper function to validate user pool security settings
func validateCognitoUserPoolSecurity(t *testing.T, region, userPoolId string) {
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
	
	// Validate email verification is required
	if userPool.AutoVerifiedAttributes != nil {
		hasEmailVerification := false
		for _, attr := range userPool.AutoVerifiedAttributes {
			if *attr == "email" {
				hasEmailVerification = true
				break
			}
		}
		assert.True(t, hasEmailVerification, "Email verification should be enabled")
	}
	
	// Validate username configuration
	if userPool.UsernameConfiguration != nil {
		// Case sensitivity should be disabled for better UX
		assert.False(t, *userPool.UsernameConfiguration.CaseSensitive,
			"Username should be case insensitive")
	}
	
	// Validate admin create user configuration
	if userPool.AdminCreateUserConfig != nil {
		// Temporary passwords should have reasonable expiry
		if userPool.AdminCreateUserConfig.TemporaryPasswordValidityDays != nil {
			assert.True(t, *userPool.AdminCreateUserConfig.TemporaryPasswordValidityDays <= 7,
				"Temporary password validity should not exceed 7 days")
		}
	}
	
	t.Logf("User pool security settings validated for %s", userPoolId)
}

// Helper function to validate account recovery settings
func validateCognitoAccountRecovery(t *testing.T, region, userPoolId string) {
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
	
	// Validate account recovery settings exist
	if userPool.AccountRecoverySetting != nil {
		require.NotNil(t, userPool.AccountRecoverySetting.RecoveryMechanisms)
		assert.True(t, len(userPool.AccountRecoverySetting.RecoveryMechanisms) > 0,
			"At least one recovery mechanism should be configured")
		
		// Validate recovery mechanisms are secure
		for _, mechanism := range userPool.AccountRecoverySetting.RecoveryMechanisms {
			assert.True(t, *mechanism.Name == "verified_email" || *mechanism.Name == "verified_phone_number",
				"Recovery mechanism should be verified_email or verified_phone_number")
			assert.True(t, *mechanism.Priority >= 1, "Recovery mechanism priority should be >= 1")
		}
		
		t.Logf("Account recovery settings validated for user pool %s", userPoolId)
	} else {
		t.Logf("No explicit account recovery settings configured for user pool %s", userPoolId)
	}
}

// Helper function to run comprehensive compliance checks
func validateCognitoComplianceChecks(t *testing.T, region, userPoolId, clientId string) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	cognitoClient := cognitoidentityprovider.New(sess)
	
	// Validate user pool exists and is accessible
	userPoolResult, err := cognitoClient.DescribeUserPool(&cognitoidentityprovider.DescribeUserPoolInput{
		UserPoolId: aws.String(userPoolId),
	})
	require.NoError(t, err)
	require.NotNil(t, userPoolResult.UserPool)
	
	// Validate client exists and is accessible
	clientResult, err := cognitoClient.DescribeUserPoolClient(&cognitoidentityprovider.DescribeUserPoolClientInput{
		UserPoolId: aws.String(userPoolId),
		ClientId:   aws.String(clientId),
	})
	require.NoError(t, err)
	require.NotNil(t, clientResult.UserPoolClient)
	
	userPool := userPoolResult.UserPool
	client := clientResult.UserPoolClient
	
	// Compliance check: Password policy exists and is secure
	require.NotNil(t, userPool.Policies)
	require.NotNil(t, userPool.Policies.PasswordPolicy)
	assert.True(t, *userPool.Policies.PasswordPolicy.MinimumLength >= 8,
		"Password minimum length compliance check")
	
	// Compliance check: MFA is configured
	assert.True(t, *userPool.MfaConfiguration != "OFF",
		"MFA should be configured for compliance")
	
	// Compliance check: Secure auth flows only
	require.NotNil(t, client.ExplicitAuthFlows)
	for _, flow := range client.ExplicitAuthFlows {
		assert.True(t, *flow != "ALLOW_ADMIN_USER_PASSWORD_AUTH",
			"Admin password auth should not be enabled for compliance")
	}
	
	// Compliance check: Token validity periods are reasonable
	if client.AccessTokenValidity != nil {
		assert.True(t, *client.AccessTokenValidity <= 24,
			"Access token validity compliance check")
	}
	
	// Compliance check: User pool has proper configuration
	assert.NotEmpty(t, *userPool.Name, "User pool should have a name")
	
	t.Logf("Compliance checks passed for user pool %s and client %s", userPoolId, clientId)
}