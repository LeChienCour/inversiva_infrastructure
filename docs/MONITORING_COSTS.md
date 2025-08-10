# Monitoring Cost Optimization Guide

This guide provides detailed cost analysis and optimization strategies for the monitoring infrastructure.

## 💰 Cost Breakdown

### AWS Service Costs (Monthly)

| Service | Development | Production | Notes |
|---------|-------------|------------|-------|
| SNS Topic | Free | Free | First 1,000 email notifications/month |
| Budget | Free | Free | First 2 budgets per account |
| CloudWatch Alarms | $0.10 | $0.30 | $0.10 per alarm |
| CloudWatch Dashboard | $0 (disabled) | $3.00 | $3.00 per dashboard |
| CloudTrail | $0 (disabled) | $2.00+ | $2.00 + data events |
| CloudWatch Logs | $0.50 | $1.50 | ~$0.50 per GB ingested |
| **Total Estimated** | **~$0.60** | **~$6.80** | |

### Cost Optimization Strategies

#### Ultra-Low Cost Development (~$0.60/month)
```hcl
# Disable expensive features
enable_dashboard          = false  # Save $3.00/month
enable_cloudtrail        = false  # Save $2.00/month
enable_performance_alarms = false  # Save $0.20/month

# Minimize log costs
log_retention_days = 1            # Minimum retention
monthly_budget_limit = "5"        # Low budget threshold
cost_alarm_threshold = "1"        # Alert on $1/day spending
```

#### Cost-Optimized Production (~$6.80/month)
```hcl
# Keep essential features only
enable_dashboard          = true   # $3.00 for visibility
enable_cloudtrail        = true   # $2.00 for security
enable_performance_alarms = true   # $0.30 for critical alerts

# Optimize retention and thresholds
log_retention_days = 30           # Reduced from 90 days
monthly_budget_limit = "50"       # Reduced from $200
cost_alarm_threshold = "3"        # Alert on $3/day spending
```

## 🎯 Feature Cost Analysis

### CloudWatch Dashboard ($3.00/month)
**What it provides:**
- Visual metrics dashboard
- Real-time monitoring charts
- Custom metric visualization

**Cost-saving alternatives:**
- Use AWS CLI to query metrics: `aws cloudwatch get-metric-statistics`
- Use CloudWatch Insights for ad-hoc queries
- Enable only for production environments

### CloudTrail ($2.00+/month)
**What it provides:**
- API call logging
- Security event monitoring
- Compliance audit trail

**Cost-saving strategies:**
- Disable in development environments
- Use data events selectively
- Implement log lifecycle policies

### CloudWatch Alarms ($0.10 each)
**Essential alarms to keep:**
- Cost monitoring alarm (critical)
- CloudFront error rate (production only)

**Alarms you can disable:**
- Cache hit rate monitoring
- S3 error rate monitoring
- Detailed performance metrics

### CloudWatch Logs ($0.50/GB)
**Cost-saving strategies:**
- Use 1-day retention in development
- Use 30-day retention in production (vs 90 days)
- Filter logs to reduce volume
- Use log groups selectively

## 📊 Cost Comparison

### Traditional Monitoring Setup
```
CloudWatch Dashboard:     $3.00/month
CloudTrail:              $2.00/month
5 CloudWatch Alarms:     $0.50/month
CloudWatch Logs (90d):   $2.00/month
Total:                   $7.50/month per environment
```

### Our Optimized Setup

#### Development Environment
```
CloudWatch Dashboard:     $0.00 (disabled)
CloudTrail:              $0.00 (disabled)
1 CloudWatch Alarm:      $0.10/month
CloudWatch Logs (1d):    $0.50/month
Total:                   $0.60/month
```

#### Production Environment
```
CloudWatch Dashboard:     $3.00/month
CloudTrail:              $2.00/month
3 CloudWatch Alarms:     $0.30/month
CloudWatch Logs (30d):   $1.50/month
Total:                   $6.80/month
```

**Total Savings: ~$8.40/month** (compared to traditional setup for both environments)

## 🔧 Implementation Guide

### Step 1: Ultra-Low Cost Development
```hcl
module "monitoring" {
  source = "../../modules/monitoring"
  
  # Minimal configuration
  monthly_budget_limit       = "5"
  enable_dashboard          = false
  enable_cloudtrail        = false
  enable_performance_alarms = false
  enable_cost_alarms        = true
  log_retention_days        = 1
  cost_alarm_threshold      = "1"
}
```

### Step 2: Cost-Optimized Production
```hcl
module "monitoring" {
  source = "../../modules/monitoring"
  
  # Essential features only
  monthly_budget_limit       = "50"
  enable_dashboard          = true
  enable_cloudtrail        = true
  enable_performance_alarms = true
  enable_cost_alarms        = true
  log_retention_days        = 30
  cost_alarm_threshold      = "3"
}
```

### Step 3: Monitor Your Monitoring Costs
```bash
# Check your actual monitoring costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

## 🚨 Cost Alerts Setup

### Daily Cost Monitoring
The module includes daily cost alarms that will alert you if spending exceeds:
- **Development**: $1/day ($30/month equivalent)
- **Production**: $3/day ($90/month equivalent)

### Budget Alerts
Monthly budget alerts at:
- **80% of budget**: Warning email
- **100% of budget**: Critical email

### Cost Spike Detection
Automatic detection of unusual spending patterns with immediate alerts.

## 📈 Scaling Considerations

### When to Enable More Features

#### Enable Dashboard When:
- Team size > 3 people
- Need real-time monitoring
- Troubleshooting performance issues
- Production environment

#### Enable CloudTrail When:
- Security compliance required
- Production environment
- Audit trail needed
- Regulatory requirements

#### Enable Performance Alarms When:
- SLA requirements exist
- Customer-facing application
- Performance is critical
- Production environment

## 🎛️ Advanced Cost Optimization

### Custom Metrics (Free Tier)
AWS provides 10 custom metrics free per month. Use them wisely:
```hcl
# Example: Application-specific metric
resource "aws_cloudwatch_log_metric_filter" "app_errors" {
  name           = "application-errors"
  log_group_name = "/aws/lambda/my-app"
  pattern        = "[timestamp, request_id, ERROR]"
  
  metric_transformation {
    name      = "ApplicationErrors"
    namespace = "MyApp/Errors"
    value     = "1"
  }
}
```

### Log Filtering to Reduce Costs
```hcl
# Filter out noisy logs
resource "aws_cloudwatch_log_metric_filter" "important_only" {
  name           = "important-events"
  log_group_name = aws_cloudwatch_log_group.app_logs.name
  pattern        = "[timestamp, level=ERROR]"  # Only ERROR level
}
```

### Scheduled Monitoring
For non-critical environments, consider scheduled monitoring:
```bash
# Enable monitoring during business hours only
aws events put-rule --name "enable-monitoring" --schedule-expression "cron(0 9 * * MON-FRI *)"
aws events put-rule --name "disable-monitoring" --schedule-expression "cron(0 18 * * MON-FRI *)"
```

## 📋 Cost Monitoring Checklist

### Weekly Tasks
- [ ] Review cost alerts and spending trends
- [ ] Check if any alarms are consistently firing (may need threshold adjustment)
- [ ] Verify log retention policies are appropriate

### Monthly Tasks
- [ ] Review actual vs budgeted costs
- [ ] Analyze which services are driving costs
- [ ] Consider disabling unused features
- [ ] Update budget thresholds if needed

### Quarterly Tasks
- [ ] Review monitoring requirements vs actual usage
- [ ] Consider enabling/disabling features based on needs
- [ ] Optimize log retention periods
- [ ] Review alarm thresholds and reduce false positives

## 🆘 Emergency Cost Controls

If costs spike unexpectedly:

1. **Immediate Actions:**
   ```bash
   # Disable expensive features temporarily
   terragrunt apply -var="enable_dashboard=false"
   terragrunt apply -var="enable_cloudtrail=false"
   ```

2. **Investigate Costs:**
   ```bash
   # Check cost breakdown
   aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-31 --granularity DAILY --metrics BlendedCost
   ```

3. **Reduce Log Retention:**
   ```bash
   # Temporarily reduce log retention
   terragrunt apply -var="log_retention_days=1"
   ```

## 💡 Pro Tips

1. **Use AWS Free Tier**: First 1,000 SNS emails and first 2 budgets are free
2. **Batch Notifications**: Group multiple alerts into single emails
3. **Use CloudWatch Insights**: Query logs without storing them long-term
4. **Monitor Your Monitoring**: Set up cost alerts for monitoring services themselves
5. **Regional Optimization**: Use cheaper regions for non-production monitoring

## 📞 Support

For cost optimization questions:
- Review AWS Cost Explorer monthly
- Use AWS Trusted Advisor for recommendations
- Consider AWS Support for cost optimization guidance
- Monitor this documentation for updates