# S3 Website Hosting Module Outputs

output "bucket_id" {
  description = "ID of the S3 bucket"
  value       = aws_s3_bucket.website.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.website.arn
}

output "bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.website.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.website.bucket_regional_domain_name
}

output "website_endpoint" {
  description = "Website endpoint of the S3 bucket"
  value       = aws_s3_bucket_website_configuration.website.website_endpoint
}

output "website_domain" {
  description = "Domain of the website endpoint"
  value       = aws_s3_bucket_website_configuration.website.website_domain
}

output "origin_access_control_id" {
  description = "ID of the CloudFront Origin Access Control"
  value       = aws_cloudfront_origin_access_control.website.id
}

output "origin_access_control_etag" {
  description = "ETag of the CloudFront Origin Access Control"
  value       = aws_cloudfront_origin_access_control.website.etag
}

output "bucket_name" {
  description = "Name of the S3 bucket (for reference in other modules)"
  value       = aws_s3_bucket.website.id
}

output "versioning_enabled" {
  description = "Whether versioning is enabled on the bucket"
  value       = var.enable_versioning
}

output "lifecycle_policy_enabled" {
  description = "Whether lifecycle policy is enabled on the bucket"
  value       = var.enable_lifecycle_policy
}

# Security-related outputs
output "encryption_type" {
  description = "Type of encryption used for the bucket"
  value       = "AES256"
}

output "object_lock_enabled" {
  description = "Whether object lock is enabled on the bucket"
  value       = var.enable_object_lock
}

output "intelligent_tiering_enabled" {
  description = "Whether intelligent tiering is enabled on the bucket"
  value       = var.enable_intelligent_tiering
}

output "access_logging_enabled" {
  description = "Whether access logging is enabled on the bucket"
  value       = var.access_logging_bucket != null
}