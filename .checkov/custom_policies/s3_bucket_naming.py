"""
Custom Checkov policy to enforce S3 bucket naming conventions
"""
from checkov.common.models.enums import TRUE_VALUES
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck
from checkov.common.models.enums import CheckResult, CheckCategories
import re


class S3BucketNamingConvention(BaseResourceCheck):
    def __init__(self):
        name = "Ensure S3 bucket follows organization naming convention"
        id = "CKV2_AWS_S3_NAMING"
        supported_resources = ['aws_s3_bucket']
        categories = [CheckCategories.GENERAL_SECURITY]
        super().__init__(name=name, id=id, categories=categories, supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        """
        Looks for S3 bucket naming convention:
        - Must start with project name prefix
        - Must include environment (dev/prod)
        - Must be lowercase
        - Must not exceed 63 characters
        """
        bucket_name = conf.get('bucket')
        if bucket_name and isinstance(bucket_name, list):
            bucket_name = bucket_name[0]
        
        if not bucket_name:
            return CheckResult.UNKNOWN
        
        # Convert to string if it's a reference
        bucket_name_str = str(bucket_name)
        
        # Check if it's a variable reference (acceptable)
        if bucket_name_str.startswith('${') or bucket_name_str.startswith('var.'):
            return CheckResult.PASSED
        
        # Check naming convention
        pattern = r'^[a-z0-9][a-z0-9-]*-(dev|prod|test)-[a-z0-9-]+$'
        if not re.match(pattern, bucket_name_str):
            return CheckResult.FAILED
        
        # Check length
        if len(bucket_name_str) > 63:
            return CheckResult.FAILED
        
        return CheckResult.PASSED


check = S3BucketNamingConvention()