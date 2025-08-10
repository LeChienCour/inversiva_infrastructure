"""
Custom Checkov policy to enforce Cognito security requirements
"""
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck
from checkov.common.models.enums import CheckResult, CheckCategories


class CognitoPasswordPolicy(BaseResourceCheck):
    def __init__(self):
        name = "Ensure Cognito User Pool has strong password policy"
        id = "CKV2_AWS_COGNITO_PASSWORD"
        supported_resources = ['aws_cognito_user_pool']
        categories = [CheckCategories.IAM]
        super().__init__(name=name, id=id, categories=categories, supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        """
        Ensure Cognito User Pool has strong password policy:
        - Minimum length >= 12
        - Requires uppercase, lowercase, numbers, and symbols
        """
        password_policy = conf.get('password_policy')
        if not password_policy or not isinstance(password_policy, list):
            return CheckResult.FAILED
        
        policy = password_policy[0]
        if not isinstance(policy, dict):
            return CheckResult.FAILED
        
        # Check minimum length
        min_length = policy.get('minimum_length')
        if not min_length or (isinstance(min_length, list) and min_length[0] < 12):
            return CheckResult.FAILED
        
        # Check required character types
        required_checks = [
            'require_lowercase',
            'require_uppercase', 
            'require_numbers',
            'require_symbols'
        ]
        
        for check in required_checks:
            value = policy.get(check)
            if not value or (isinstance(value, list) and not value[0]):
                return CheckResult.FAILED
        
        return CheckResult.PASSED


class CognitoMFAConfiguration(BaseResourceCheck):
    def __init__(self):
        name = "Ensure Cognito User Pool has MFA enabled for production"
        id = "CKV2_AWS_COGNITO_MFA"
        supported_resources = ['aws_cognito_user_pool']
        categories = [CheckCategories.IAM]
        super().__init__(name=name, id=id, categories=categories, supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        """
        Ensure MFA is configured appropriately based on environment
        """
        # Check if this is a production environment resource
        tags = conf.get('tags', [{}])
        if isinstance(tags, list) and tags:
            tags_dict = tags[0]
            environment = tags_dict.get('Environment', [''])[0] if isinstance(tags_dict.get('Environment'), list) else tags_dict.get('Environment', '')
            
            # For production, MFA should be enabled
            if environment.lower() == 'prod' or environment.lower() == 'production':
                mfa_config = conf.get('mfa_configuration')
                if not mfa_config or (isinstance(mfa_config, list) and mfa_config[0] == 'OFF'):
                    return CheckResult.FAILED
        
        return CheckResult.PASSED


check1 = CognitoPasswordPolicy()
check2 = CognitoMFAConfiguration()