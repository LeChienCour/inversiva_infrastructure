"""
Custom Checkov policy to enforce CloudFront security requirements
"""
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck
from checkov.common.models.enums import CheckResult, CheckCategories


class CloudFrontSecurityHeaders(BaseResourceCheck):
    def __init__(self):
        name = "Ensure CloudFront distribution has security headers configured"
        id = "CKV2_AWS_CLOUDFRONT_HEADERS"
        supported_resources = ['aws_cloudfront_distribution']
        categories = [CheckCategories.NETWORKING]
        super().__init__(name=name, id=id, categories=categories, supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        """
        Ensure CloudFront has security headers in response headers policy
        """
        default_cache_behavior = conf.get('default_cache_behavior')
        if not default_cache_behavior or not isinstance(default_cache_behavior, list):
            return CheckResult.FAILED
        
        behavior = default_cache_behavior[0]
        if not isinstance(behavior, dict):
            return CheckResult.FAILED
        
        # Check for response headers policy
        response_headers_policy_id = behavior.get('response_headers_policy_id')
        if not response_headers_policy_id:
            return CheckResult.FAILED
        
        return CheckResult.PASSED


class CloudFrontTLSVersion(BaseResourceCheck):
    def __init__(self):
        name = "Ensure CloudFront distribution uses minimum TLS 1.2"
        id = "CKV2_AWS_CLOUDFRONT_TLS"
        supported_resources = ['aws_cloudfront_distribution']
        categories = [CheckCategories.NETWORKING]
        super().__init__(name=name, id=id, categories=categories, supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        """
        Ensure CloudFront uses minimum TLS 1.2
        """
        viewer_certificate = conf.get('viewer_certificate')
        if not viewer_certificate or not isinstance(viewer_certificate, list):
            return CheckResult.FAILED
        
        cert_config = viewer_certificate[0]
        if not isinstance(cert_config, dict):
            return CheckResult.FAILED
        
        # Check minimum protocol version
        min_protocol_version = cert_config.get('minimum_protocol_version')
        if not min_protocol_version:
            return CheckResult.FAILED
        
        # Acceptable TLS versions (1.2 and above)
        acceptable_versions = ['TLSv1.2_2021', 'TLSv1.2_2019', 'TLSv1.2_2018']
        
        if isinstance(min_protocol_version, list):
            version = min_protocol_version[0]
        else:
            version = min_protocol_version
        
        if version not in acceptable_versions:
            return CheckResult.FAILED
        
        return CheckResult.PASSED


check1 = CloudFrontSecurityHeaders()
check2 = CloudFrontTLSVersion()