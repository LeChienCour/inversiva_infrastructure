# Monitoring Module

This Terraform module creates comprehensive monitoring and alerting infrastructure for the Next.js application deployment on AWS. It includes CloudWatch dashboards, cost budgets, security monitoring with CloudTrail, and performance monitoring for CloudFront and S3.

## Features

- **CloudWatch Dashboard**: Visual monitoring of infrastructure metrics
- **Cost Budgets**: Automated cost monitoring with email alerts
- **Security Monitoring**: CloudTrail integration with security event alerts
- **Performance Monitoring**: CloudFront and S3 performance alarms
- **SNS Notifications**: Email alerts for all monitoring events

## Resources Created

### Monitoring Infrastructure
- CloudWatch Dashboard for infrastructure metrics
- SNS Topic and subscriptions for alert notifications
- CloudWatch Log Groups for centralized logging

### Cost Management
- AWS Budgets for cost monitoring
- Budget alerts at 80% (actual) and 100% (forecasted) thresholds

### Security Monitoring
- CloudTrail for API call logging
- S3 bucket for CloudTrail logs with encryption and versioning
- CloudWatch metric filters for security events
- Alarms for unauthorized API calls

### Performance Monitoring
- CloudFront error rate monitoring
- CloudFront cache hit rate monitoring
- S3 error rate monitoring

## Usage

```hcl
module "monitoring" {
  source = "../../modules/monitoring"

  project_name               = "my-nextjs-app"
  environment               = "prod"
  cloudfront_distribution_id = module.cloudfront.distribution_id
  website_bucket_name       = module.s3_website.bucket_name
  website_bucket_arn        = module.s3_website.bucket_arn
  content_bucket_name       = module.s3_content.bucket_name
  content_bucket_arn        = module.s3_content.bucket_arn
  
  alert_email_addresses = ["admin@example.com", "devops@example.com"]
  monthly_budget_limit  = "100"
  enable_cloudtrail     = true
  log_retention_days    = 30
}
```

## Environment-Specific Configurations

### Ultra-Low Cost Development
```hcl
monthly_budget_limit       = "5"
enable_cloudtrail         = false
enable_dashboard          = false
enable_performance_alarms = false
enable_cost_alarms        = true
log_retention_days        = 1
cost_alarm_threshold      = "1"
```

### Cost-Optimized Production
```hcl
monthly_budget_limit       = "50"
enable_cloudtrail         = true
enable_dashboard          = true
enable_performance_alarms = true
enable_cost_alarms        = true
log_retention_days        = 30
cost_alarm_threshold      = "3"
```

## Monitoring Metrics

### CloudFront Metrics
- **Requests**: Number of requests to CloudFront
- **BytesDownloaded**: Data transferred from CloudFront to viewers
- **BytesUploaded**: Data transferred from viewers to CloudFront
- **4xxErrorRate**: Percentage of 4xx errors
- **CacheHitRate**: Percentage of requests served from cache

### S3 Metrics
- **BucketSizeBytes**: Size of S3 buckets
- **NumberOfObjects**: Number of objects in S3 buckets
- **4xxErrors**: Number of 4xx errors from S3

### Security Metrics
- **UnauthorizedAPICalls**: Count of unauthorized API calls
- **AccessDenied**: Count of access denied events

## Alerts and Thresholds

### Cost Alerts
- **80% of budget**: Actual spending alert
- **100% of budget**: Forecasted spending alert

### Performance Alerts
- **CloudFront 4xx Error Rate**: > 5% average over 10 minutes
- **CloudFront Cache Hit Rate**: < 80% average over 15 minutes
- **S3 4xx Errors**: > 10 errors in 5 minutes

### Security Alerts
- **Unauthorized API Calls**: Any occurrence triggers immediate alert

## Dashboard Access

After deployment, access your CloudWatch dashboard at:
```
https://{region}.console.aws.amazon.com/cloudwatch/home?region={region}#dashboards:name={project-name}-{environment}-infrastructure
```

## Cost Optimization

This module is designed for **ultra-low cost monitoring** with optional features that can be disabled to save money.

### Cost Breakdown (Monthly Estimates)
- **SNS Topic**: Free (first 1,000 email notifications)
- **Budget**: Free (first 2 budgets per account)
- **CloudWatch Alarms**: ~$0.10 per alarm
- **CloudWatch Dashboard**: ~$3.00 per dashboard (can be disabled)
- **CloudTrail**: ~$2.00+ per month (can be disabled)
- **CloudWatch Logs**: ~$0.50 per GB (minimize with short retention)

### Ultra-Low Cost Configuration (~$0.60/month)
```hcl
enable_dashboard          = false  # Save ~$3/month
enable_cloudtrail        = false  # Save ~$2/month  
enable_performance_alarms = false  # Save ~$0.20/month
log_retention_days       = 1      # Minimize log costs
monthly_budget_limit     = "5"    # Low budget threshold
cost_alarm_threshold     = "1"    # Alert on $1/day spending
```

### Development Environment (Ultra-Low Cost)
- Dashboard disabled (save $3/month)
- CloudTrail disabled (save $2/month)
- Performance alarms disabled (save $0.20/month)
- 1-day log retention (minimize costs)
- Only cost monitoring enabled
- **Total: ~$0.60/month**

### Production Environment (Cost-Optimized)
- Dashboard enabled for visibility
- CloudTrail enabled for security
- Essential performance alarms only
- 30-day log retention (reduced from 90)
- **Total: ~$6/month**

## Security Considerations

- CloudTrail logs are encrypted at rest
- S3 bucket policies restrict access to CloudTrail service
- Log groups have configurable retention periods
- SNS topics use encryption in transit

## Troubleshooting

### Common Issues

1. **SNS Subscription Not Confirmed**
   - Check email for confirmation link
   - Verify email addresses are correct

2. **CloudTrail Permissions**
   - Ensure CloudTrail service has S3 bucket permissions
   - Check bucket policy is correctly applied

3. **Budget Alerts Not Working**
   - Verify cost filters match resource tags
   - Check budget thresholds are appropriate

4. **Dashboard Not Showing Data**
   - Ensure resource IDs are correctly passed
   - Check that resources exist and are generating metrics

### Monitoring Health

Use these commands to verify monitoring setup:

```bash
# Check SNS topic subscriptions
aws sns list-subscriptions-by-topic --topic-arn <sns-topic-arn>

# Verify CloudTrail status
aws cloudtrail get-trail-status --name <trail-name>

# Check budget status
aws budgets describe-budget --account-id <account-id> --budget-name <budget-name>
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Name of the project | `string` | n/a | yes |
| environment | Environment name (dev/prod) | `string` | n/a | yes |
| cloudfront_distribution_id | CloudFront distribution ID | `string` | n/a | yes |
| website_bucket_name | S3 website bucket name | `string` | n/a | yes |
| website_bucket_arn | S3 website bucket ARN | `string` | n/a | yes |
| content_bucket_name | S3 content bucket name | `string` | n/a | yes |
| content_bucket_arn | S3 content bucket ARN | `string` | n/a | yes |
| alert_email_addresses | Email addresses for alerts | `list(string)` | `[]` | no |
| monthly_budget_limit | Monthly budget limit in USD | `string` | `"50"` | no |
| enable_cloudtrail | Enable CloudTrail logging | `bool` | `true` | no |
| log_retention_days | CloudWatch log retention days | `number` | `30` | no |
| cognito_user_pool_id | Cognito User Pool ID | `string` | `""` | no |
| enable_detailed_monitoring | Enable detailed monitoring | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| sns_topic_arn | ARN of the SNS topic for alerts |
| dashboard_url | URL of the CloudWatch dashboard |
| budget_name | Name of the cost budget |
| cloudtrail_arn | ARN of the CloudTrail |
| cloudtrail_bucket_name | Name of the CloudTrail S3 bucket |
| log_group_name | Name of the CloudTrail log group |
| alarm_names | List of CloudWatch alarm names |