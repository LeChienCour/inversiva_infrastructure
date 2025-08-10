package modules

import (
	"testing"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/acm"
	"github.com/aws/aws-sdk-go/service/route53"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-nextjs-infrastructure/test/helpers"
)

func TestRoute53ACMModule(t *testing.T) {
	t.Parallel()

	// Setup test configuration
	testConfig := helpers.NewTestConfig(t)
	
	// Define test variables
	vars := map[string]interface{}{
		"domain_name":    "test-" + testConfig.UniqueID + ".example.com",
		"environment":    testConfig.Environment,
		"create_zone":    true,
		"subject_alternative_names": []string{
			"www.test-" + testConfig.UniqueID + ".example.com",
		},
		"tags": map[string]string{
			"Environment": testConfig.Environment,
			"Testing":     "true",
		},
	}

	// Configure Terraform options
	terraformOptions := testConfig.GetTerraformOptions("../../modules/route53-acm", vars)
	
	// Cleanup resources after test
	helpers.CleanupTerraform(t, terraformOptions, testConfig.Cleanup)

	// Run terraform init and apply
	terraform.InitAndApply(t, terraformOptions)

	// Validate outputs
	hostedZoneId := terraform.Output(t, terraformOptions, "hosted_zone_id")
	certificateArn := terraform.Output(t, terraformOptions, "certificate_arn")
	nameServers := terraform.OutputList(t, terraformOptions, "name_servers")

	// Assertions
	assert.NotEmpty(t, hostedZoneId)
	assert.NotEmpty(t, certificateArn)
	assert.NotEmpty(t, nameServers)
	assert.Contains(t, certificateArn, "arn:aws:acm")
	assert.True(t, len(nameServers) >= 2) // Route53 provides at least 2 name servers

	// Validate Route53 hosted zone
	t.Run("ValidateHostedZone", func(t *testing.T) {
		validateHostedZone(t, testConfig.Region, hostedZoneId, vars)
	})

	// Validate ACM certificate
	t.Run("ValidateACMCertificate", func(t *testing.T) {
		validateACMCertificate(t, testConfig.Region, certificateArn, vars)
	})
}

func TestRoute53ACMModuleExistingZone(t *testing.T) {
	t.Parallel()

	// Setup test configuration
	testConfig := helpers.NewTestConfig(t)
	
	// First create a hosted zone
	setupVars := map[string]interface{}{
		"domain_name": "existing-" + testConfig.UniqueID + ".example.com",
		"environment": testConfig.Environment,
		"create_zone": true,
	}

	setupOptions := testConfig.GetTerraformOptions("../../modules/route53-acm", setupVars)
	terraform.InitAndApply(t, setupOptions)
	
	existingZoneId := terraform.Output(t, setupOptions, "hosted_zone_id")
	
	// Now test using existing zone
	vars := map[string]interface{}{
		"domain_name":      "existing-" + testConfig.UniqueID + ".example.com",
		"environment":      testConfig.Environment,
		"create_zone":      false,
		"hosted_zone_id":   existingZoneId,
	}

	// Configure Terraform options for the actual test
	terraformOptions := testConfig.GetTerraformOptions("../../modules/route53-acm", vars)
	
	// Cleanup both deployments
	defer terraform.Destroy(t, setupOptions)
	helpers.CleanupTerraform(t, terraformOptions, testConfig.Cleanup)

	// Run terraform init and apply
	terraform.InitAndApply(t, terraformOptions)

	// Validate certificate was created with existing zone
	certificateArn := terraform.Output(t, terraformOptions, "certificate_arn")
	outputZoneId := terraform.Output(t, terraformOptions, "hosted_zone_id")

	assert.NotEmpty(t, certificateArn)
	assert.Equal(t, existingZoneId, outputZoneId)
}

func TestRoute53ACMModuleMinimalConfig(t *testing.T) {
	t.Parallel()

	// Setup test configuration
	testConfig := helpers.NewTestConfig(t)
	
	// Define minimal test variables
	vars := map[string]interface{}{
		"domain_name": "minimal-" + testConfig.UniqueID + ".example.com",
		"environment": testConfig.Environment,
	}

	// Configure Terraform options
	terraformOptions := testConfig.GetTerraformOptions("../../modules/route53-acm", vars)
	
	// Cleanup resources after test
	helpers.CleanupTerraform(t, terraformOptions, testConfig.Cleanup)

	// Run terraform init and apply
	terraform.InitAndApply(t, terraformOptions)

	// Validate basic outputs exist
	hostedZoneId := terraform.Output(t, terraformOptions, "hosted_zone_id")
	certificateArn := terraform.Output(t, terraformOptions, "certificate_arn")

	assert.NotEmpty(t, hostedZoneId)
	assert.NotEmpty(t, certificateArn)
}

// Helper function to validate Route53 hosted zone
func validateHostedZone(t *testing.T, region, hostedZoneId string, vars map[string]interface{}) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	route53Client := route53.New(sess)
	
	result, err := route53Client.GetHostedZone(&route53.GetHostedZoneInput{
		Id: aws.String(hostedZoneId),
	})
	require.NoError(t, err)
	require.NotNil(t, result.HostedZone)
	
	hostedZone := result.HostedZone
	
	// Validate domain name
	if domainName, ok := vars["domain_name"].(string); ok {
		// Route53 adds a trailing dot to domain names
		expectedName := domainName + "."
		assert.Equal(t, expectedName, *hostedZone.Name)
	}
	
	// Validate hosted zone is not private
	assert.False(t, *hostedZone.Config.PrivateZone)
}

// Helper function to validate ACM certificate
func validateACMCertificate(t *testing.T, region, certificateArn string, vars map[string]interface{}) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)
	
	acmClient := acm.New(sess)
	
	result, err := acmClient.DescribeCertificate(&acm.DescribeCertificateInput{
		CertificateArn: aws.String(certificateArn),
	})
	require.NoError(t, err)
	require.NotNil(t, result.Certificate)
	
	certificate := result.Certificate
	
	// Validate domain name
	if domainName, ok := vars["domain_name"].(string); ok {
		assert.Equal(t, domainName, *certificate.DomainName)
	}
	
	// Validate subject alternative names
	if sans, ok := vars["subject_alternative_names"].([]string); ok {
		require.Equal(t, len(sans)+1, len(certificate.SubjectAlternativeNames)) // +1 for primary domain
		
		// Check that all SANs are present
		sanMap := make(map[string]bool)
		for _, san := range certificate.SubjectAlternativeNames {
			sanMap[*san] = true
		}
		
		for _, expectedSan := range sans {
			assert.True(t, sanMap[expectedSan], "Expected SAN %s not found", expectedSan)
		}
	}
	
	// Validate certificate type
	assert.Equal(t, "AMAZON_ISSUED", *certificate.Type)
	
	// Validate key algorithm
	assert.Equal(t, "RSA-2048", *certificate.KeyAlgorithm)
	
	// Validate validation method
	require.NotEmpty(t, certificate.DomainValidationOptions)
	for _, validation := range certificate.DomainValidationOptions {
		assert.Equal(t, "DNS", *validation.ValidationMethod)
	}
}