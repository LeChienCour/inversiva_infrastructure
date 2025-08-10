# Monitoring and Alerting Guide

This guide covers the comprehensive monitoring and alerting infrastructure included in the Next.js Terraform deployment.

## Overview

The monitoring module provides:
- **CloudWatch Dashboards** for visual monitoring
- **Cost Budgets** with automated alerts
- **Security Monitoring** via CloudTrail
- **Performance Monitoring** for CloudFront and S3
- **SNS Notifications** for all alerts

## Components

### 1. CloudWatch Dashboard

A centralized dashboard showing key metrics:

#### CloudFront Metrics
- Request count and data transfer
- Error rates (4xx/5xx)
- Cache hit rates
- Origin response times

#### S3 Metrics
- Bucket size and object count
- Request metrics
- Error rates

#### Security Metrics
- Unauthorized API calls
- Access denied events
- CloudTrail logging status

### 2. Cost Management

#### Budget Configuration
- **Development**: $25/month default
- **Development**: $5/month (ultra-low cost)
- **Production**: $50/month (cost-optimized)
- **Daily Alerts**: $1/day (dev), $3/day (prod)
- **Budget Alerts**: 80% actual, 100% forecasted

#### Aggressive Cost Optimization Features
- **Dashboard disabled in dev** (saves $3/month)
- **CloudTrail disabled in dev** (saves $2/month)
- **Minimal alarms** (saves $0.20/month)
- **1-day log retention in dev** (minimizes log costs)
- **Essential monitoring only**
- **Total dev monitoring cost: ~$0.60/month**

### 3. Security Monitoring

#### CloudTrail Integration
- **Production**: Full API logging enabled
- **Development**: Disabled for cost optimization
- **Log Retention**: 90 days (prod), 7 days (dev)

#### Security Alerts
- Unauthorized API calls
- Access denied events
- Suspicious activity patterns
- Failed authentication attempts

### 4. Performance Monitoring

#### CloudFront Alarms
- **4xx Error Rate**: > 5% triggers alert
- **Cache Hit Rate**: < 80% triggers alert
- **Origin Response Time**: > 5s triggers alert

#### S3 Alarms
- **4xx Errors**: > 10 errors in 5 minutes
- **Request Rate**: Unusual spikes
- **Storage Growth**: Rapid increases

## Configuration

### Environment Variables

```hcl
# Ultra-Low Cost Development Environment
inputs = {
  alert_email_addresses      = ["dev-team@example.com"]
  monthly_budget_limit       = "5"     # Very low budget
  enable_cloudtrail         = false    # Save ~$2/month
  enable_dashboard          = false    # Save ~$3/month
  enable_performance_alarms = false    # Save ~$0.20/month
  enable_cost_alarms        = true     # Keep cost monitoring
  log_retention_days        = 1        # Minimize log costs
  cost_alarm_threshold      = "1"      # Alert on $1/day
}

# Cost-Optimized Production Environment
inputs = {
  alert_email_addresses      = ["ops@example.com"]
  monthly_budget_limit       = "50"    # Reduced from $200
  enable_cloudtrail         = true     # Keep security monitoring
  enable_dashboard          = true     # Keep for visibility
  enable_performance_alarms = true     # Essential alarms only
  enable_cost_alarms        = true     # Keep cost monitoring
  log_retention_days        = 30       # Reduced from 90 days
  cost_alarm_threshold      = "3"      # Alert on $3/day
}
```

### Email Notifications

Configure email addresses in your Terragrunt configuration:

```hcl
inputs = {
  alert_email_addresses = [
    "ops-team@company.com",
    "admin@company.com",
    "security@company.com"
  ]
}
```

**Important**: You must confirm SNS subscriptions via email after deployment.

## Accessing Monitoring

### CloudWatch Dashboard

After deployment, access your dashboard at:
```
https://{region}.console.aws.amazon.com/cloudwatch/home?region={region}#dashboards:name={project-name}-{environment}-infrastructure
```

### Budget Monitoring

View cost budgets in the AWS Billing console:
```
https://console.aws.amazon.com/billing/home#/budgets
```

### CloudTrail Logs

Access security logs in CloudWatch Logs:
```
https://{region}.console.aws.amazon.com/cloudwatch/home?region={region}#logsV2:log-groups/log-group/$252Faws$252Fcloudtrail$252F{project-name}-{environment}
```

## Health Checks

Use the provided monitoring health check scripts:

### Linux/macOS
```bash
./scripts/monitoring-health.sh -e prod -p my-project -r us-east-1
```

### Windows
```powershell
.\scripts\monitoring-health.ps1 -Environment prod -ProjectName my-project -Region us-east-1
```

### Health Check Output
```
✓ AWS CLI and credentials are configured
✓ SNS topic exists
✓ SNS topic has 2 subscription(s)
✓ CloudWatch dashboard exists
✓ Budget exists
ℹ Budget utilization: $45.67/$200 (22.8%)
✓ CloudTrail exists
✓ CloudTrail logging is enabled
✓ Found 4 CloudWatch alarm(s)
```

## Alert Types

### Cost Alerts
- **80% Budget**: Actual spending warning
- **100% Budget**: Forecasted spending alert
- **Unusual Spending**: Spike detection

### Performance Alerts
- **High Error Rate**: Application issues
- **Low Cache Hit Rate**: CDN optimization needed
- **Slow Response Times**: Performance degradation

### Security Alerts
- **Unauthorized Access**: Security breach attempts
- **Failed Authentication**: Brute force detection
- **Suspicious Activity**: Anomaly detection

## Troubleshooting

### Common Issues

#### SNS Subscriptions Not Working
1. Check email addresses are correct
2. Confirm subscriptions via email
3. Check spam folders
4. Verify SNS topic permissions

#### Dashboard Not Showing Data
1. Ensure resources exist and are generating metrics
2. Check CloudWatch permissions
3. Verify resource IDs in configuration
4. Wait for metrics to populate (up to 15 minutes)

#### Budget Alerts Not Triggering
1. Verify cost filters match resource tags
2. Check budget thresholds are appropriate
3. Ensure billing data is available
4. Confirm email subscriptions

#### CloudTrail Not Logging
1. Check CloudTrail permissions
2. Verify S3 bucket policy
3. Ensure CloudTrail is enabled
4. Check log group configuration

### Monitoring Commands

```bash
# Check SNS subscriptions
aws sns list-subscriptions-by-topic --topic-arn <topic-arn>

# Verify CloudTrail status
aws cloudtrail get-trail-status --name <trail-name>

# Check budget status
aws budgets describe-budget --account-id <account-id> --budget-name <budget-name>

# List CloudWatch alarms
aws cloudwatch describe-alarms --alarm-name-prefix <project-name>

# View dashboard
aws cloudwatch list-dashboards --dashboard-name-prefix <project-name>
```

## Best Practices

### Development Environment
- Use lower budget limits ($25-50)
- Disable CloudTrail to reduce costs
- Shorter log retention (7 days)
- Basic monitoring only
- Single email for alerts

### Production Environment
- Higher budget limits ($200+)
- Enable full CloudTrail logging
- Extended log retention (90+ days)
- Detailed monitoring enabled
- Multiple email recipients
- Slack/Teams integration

### Security Considerations
- Enable CloudTrail in production
- Monitor unauthorized access attempts
- Set up security-specific alerts
- Regular security audit reviews
- Implement least privilege access

### Cost Optimization
- Right-size budget limits
- Monitor unused resources
- Implement lifecycle policies
- Regular cost reviews
- Optimize CloudFront caching

## Integration with CI/CD

The monitoring module is automatically deployed as part of the GitHub Actions workflows:

### Development Deployment
```yaml
# Includes monitoring in component list
COMPONENTS="cognito s3-website s3-content cloudfront route53-acm monitoring"
```

### Production Deployment
```yaml
# Includes monitoring with approval gates
COMPONENTS="cognito s3-website s3-content route53-acm cloudfront monitoring"
```

### Monitoring Deployment Order
1. Core infrastructure (S3, Cognito, CloudFront)
2. Monitoring (depends on core infrastructure)
3. Verification and health checks

## Advanced Configuration

### Custom Metrics

Add application-specific metrics:

```hcl
resource "aws_cloudwatch_log_metric_filter" "application_errors" {
  name           = "${var.project_name}-application-errors"
  log_group_name = "/aws/lambda/${var.project_name}"
  pattern        = "[timestamp, request_id, ERROR]"

  metric_transformation {
    name      = "ApplicationErrors"
    namespace = "${var.project_name}/Application"
    value     = "1"
  }
}
```

### Custom Alarms

Create application-specific alarms:

```hcl
resource "aws_cloudwatch_metric_alarm" "custom_alarm" {
  alarm_name          = "${var.project_name}-custom-metric"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CustomMetric"
  namespace           = "${var.project_name}/Application"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
```

### Slack Integration

Add Slack notifications:

```hcl
resource "aws_sns_topic_subscription" "slack_alerts" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "https"
  endpoint  = var.slack_webhook_url
}
```

## Monitoring Checklist

### Initial Setup
- [ ] Configure email addresses
- [ ] Confirm SNS subscriptions
- [ ] Set appropriate budget limits
- [ ] Enable CloudTrail (production)
- [ ] Verify dashboard access

### Regular Maintenance
- [ ] Review cost trends monthly
- [ ] Check alarm states weekly
- [ ] Update email lists quarterly
- [ ] Review security logs monthly
- [ ] Optimize thresholds based on usage

### Incident Response
- [ ] Monitor alert channels
- [ ] Investigate cost spikes immediately
- [ ] Review security alerts within 1 hour
- [ ] Document incident responses
- [ ] Update monitoring based on lessons learned

## Support

For monitoring-related issues:
1. Check the troubleshooting section
2. Run health check scripts
3. Review CloudWatch logs
4. Check AWS service health dashboard
5. Contact your DevOps team