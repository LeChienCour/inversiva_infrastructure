# S3 Content Storage Module Outputs

output "bucket_id" {
  description = "The ID of the S3 content bucket"
  value       = aws_s3_bucket.content_bucket.id
}

output "bucket_arn" {
  description = "The ARN of the S3 content bucket"
  value       = aws_s3_bucket.content_bucket.arn
}

output "bucket_name" {
  description = "The name of the S3 content bucket"
  value       = aws_s3_bucket.content_bucket.bucket
}

output "bucket_domain_name" {
  description = "The bucket domain name for the S3 content bucket"
  value       = aws_s3_bucket.content_bucket.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "The bucket regional domain name for the S3 content bucket"
  value       = aws_s3_bucket.content_bucket.bucket_regional_domain_name
}

output "bucket_region" {
  description = "The AWS region where the S3 content bucket is located"
  value       = aws_s3_bucket.content_bucket.region
}

output "presigned_url_expiration_seconds" {
  description = "Default expiration time for presigned URLs in seconds"
  value       = var.presigned_url_expiration_seconds
}

# IAM policy document for Cognito user access
output "cognito_user_policy_json" {
  description = "IAM policy JSON for Cognito user-specific S3 access"
  value       = data.aws_iam_policy_document.cognito_user_policy.json
}

# Example presigned URL generation command (for documentation)
output "presigned_url_example_command" {
  description = "Example AWS CLI command for generating presigned URLs"
  value       = "aws s3 presign s3://${aws_s3_bucket.content_bucket.bucket}/your-object-key --expires-in ${var.presigned_url_expiration_seconds}"
}

# Cognito integration outputs
output "cognito_authenticated_role_arn" {
  description = "ARN of the IAM role for Cognito authenticated users"
  value       = aws_iam_role.cognito_authenticated_role.arn
}

output "cognito_authenticated_role_name" {
  description = "Name of the IAM role for Cognito authenticated users"
  value       = aws_iam_role.cognito_authenticated_role.name
}

# Admin policy outputs
output "admin_policy_arn" {
  description = "ARN of the IAM policy for admin operations"
  value       = aws_iam_policy.admin_policy.arn
}

output "admin_policy_name" {
  description = "Name of the IAM policy for admin operations"
  value       = aws_iam_policy.admin_policy.name
}

# User folder structure example
output "user_folder_structure_example" {
  description = "Example of how user folders are structured in S3"
  value       = "users/{cognito-user-id}/"
}