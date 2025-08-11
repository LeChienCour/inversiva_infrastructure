# Cost Optimization and Monitoring Guide

This document provides comprehensive strategies for optimizing AWS costs and implementing effective monitoring procedures for the Terraform Next.js infrastructure.

## Cost Optimization Overview

### Cost Optimization Principles

1. **Right-sizing**: Use appropriate resource sizes for each environment
2. **Environment-specific optimization**: Different strategies for dev vs prod
3. **Lifecycle management**: Automated cleanup and archival policies
4. **Monitoring and alerting**: Proactive cost management
5. **Regular reviews**: Continuous optimization opportunities

### Target Cost Ranges

| Environment | Users | Monthly Cost | Annual Cost |
|-------------|-------|--------------|-------------|
| **Development** | 5-10 | $2-5 | $24-60 |
| **Production (Small)** | 20-100 | $5-15 | $60-180 |
| **Production (Medium)** | 100-1000 | $15-50 | $180-600 |
| **Production (Large)** | 1000+ | $50+ | $600+ |

## Service-Specific Optimizations

### 1. Amazon S3 Storage Optimization

#### Storage Classes and Lifecycle Policies

```hcl
# Development Environment
resource "aws_s3_bucket_lifecycle_configuration" "dev_lifecycle" {
  bucket = aws_s3_bucket.website.id

  rule {
    id     = "dev_lifecycle"
    status = "Enabled"

    # Transition to IA after 7 days (aggressive for dev)
    transition {
      days          = 7
      storage_class = "STANDARD_IA"
    }

    # Transition to Glacier after 30 days
    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    # Delete after 90 days (short retention for dev)
    expiration {
      days = 90
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# Production Environment
resource "aws_s3_bucket_lifecycle_configuration" "prod_lifecycle" {
  bucket = aws_s3_bucket.website.id

  rule {
    id     = "prod_lifecycle"
    status = "Enabled"

    # Transition to IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Transition to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Transition to Deep Archive after 365 days
    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    # Keep for 7 years (compliance)
    expiration {
      days = 2555
    }
  }
}
```

#### Cost Comparison by Storage Class

| Storage Class | Cost per GB/month | Retrieval Cost | Use Case |
|---------------|-------------------|----------------|----------|
| **Standard** | $0.023 | None | Active data |
| **Standard-IA** | $0.0125 | $0.01/GB | Infrequent access |
| **Glacier** | $0.004 | $0.01/GB + time | Archive |
| **Deep Archive** | $0.00099 | $0.02/GB + time | Long-term archive |

#### S3 Cost Optimization Checklist

- [ ] **Lifecycle Policies**: Configured for automatic transitions
- [ ] **Versioning**: Enabled but with cleanup policies
- [ ] **Multipart Upload Cleanup**: Automatic cleanup of failed uploads
- [ ] **Intelligent Tiering**: Disabled for small objects (monitoring cost > savings)
- [ ] **Request Patterns**: Monitor GET/PUT request costs
- [ ] **Data Transfer**: Minimize cross-region transfers

### 2. CloudFront Distribution Optimization

#### Price Class Optimization

```hcl
# Development: Regional distribution
resource "aws_cloudfront_distribution" "dev" {
  price_class = "PriceClass_100"  # North America + Europe only
  # Savings: ~60% compared to global distribution
}

# Production: Based on user geography
resource "aws_cloudfront_distribution" "prod" {
  price_class = var.global_users ? "PriceClass_All" : "PriceClass_200"
  # PriceClass_200: North America, Europe, Asia, Middle East, Africa
  # PriceClass_All: All edge locations globally
}
```

#### Caching Strategy for Cost Optimization

```hcl
# Aggressive caching for static assets
ordered_cache_behavior {
  path_pattern     = "/static/*"
  target_origin_id = "S3-Website"
  
  # Long cache times reduce origin requests
  default_ttl = 86400    # 1 day
  max_ttl     = 31536000 # 1 year
  
  # Cache based on minimal headers
  headers = []
  
  # Compress responses
  compress = true
}

# API responses with shorter cache
ordered_cache_behavior {
  path_pattern     = "/api/*"
  target_origin_id = "S3-Website"
  
  # Shorter cache for dynamic content
  default_ttl = 300   # 5 minutes
  max_ttl     = 3600  # 1 hour
}
```

#### CloudFront Cost Factors

| Factor | Cost Impact | Optimization |
|--------|-------------|--------------|
| **Data Transfer** | $0.085-0.170/GB | Use compression, caching |
| **HTTP Requests** | $0.0075/10k requests | Cache aggressively |
| **HTTPS Requests** | $0.01/10k requests | Minimize API calls |
| **Origin Requests** | Varies by origin | Maximize cache hit ratio |

### 3. Cognito Cost Optimization

#### User Pool Optimization

```hcl
# Development: Basic features only
resource "aws_cognito_user_pool" "dev" {
  # Disable advanced security features in dev
  user_pool_add_ons {
    advanced_security_mode = "OFF"  # Saves $0.05/user/month
  }
  
  # Minimal password policy
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false  # Reduce complexity
    require_uppercase = false
  }
}

# Production: Security features enabled
resource "aws_cognito_user_pool" "prod" {
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"  # Worth the cost for production
  }
  
  # Strong password policy
  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }
}
```

#### Cognito Pricing Tiers

| Tier | Monthly Active Users | Cost per User |
|------|---------------------|---------------|
| **Free Tier** | 0-50,000 | $0.00 |
| **Standard** | 50,001+ | $0.0055 |
| **Advanced Security** | Any | +$0.05 |

### 4. Route 53 and ACM Optimization

#### DNS Cost Optimization

```hcl
# Minimize health checks in development
resource "aws_route53_health_check" "dev" {
  count = var.environment == "prod" ? 1 : 0  # Skip health checks in dev
  # Saves $0.50/month per health check
}

# Use alias records instead of CNAME when possible
resource "aws_route53_record" "website" {
  type = "A"  # Alias record - no charge for queries
  
  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}
```

#### Certificate Management

```hcl
# Use ACM certificates (free with CloudFront)
resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name
  validation_method = "DNS"
  
  # Free with CloudFront, $0.75/month with ALB
  lifecycle {
    create_before_destroy = true
  }
}
```

## Environment-Specific Cost Strategies

### Development Environment Optimizations

```hcl
locals {
  dev_optimizations = {
    # Storage optimizations
    s3_storage_class = "STANDARD_IA"
    lifecycle_transition_days = 7
    version_expiration_days = 30
    
    # CloudFront optimizations
    cloudfront_price_class = "PriceClass_100"
    enable_logging = false
    enable_monitoring = false
    
    # Cognito optimizations
    advanced_security = false
    mfa_required = false
    
    # Monitoring optimizations
    detailed_monitoring = false
    log_retention_days = 7
    enable_alarms = false
  }
}
```

**Development Cost Breakdown:**
- S3 Storage: $0.50/month (10MB static + 100MB content)
- CloudFront: $0.20/month (minimal traffic, regional)
- Route53: $0.50/month (hosted zone)
- Cognito: $0.00/month (under 50k users)
- **Total: ~$1.20/month**

### Production Environment Optimizations

```hcl
locals {
  prod_optimizations = {
    # Storage optimizations
    s3_storage_class = "STANDARD"
    lifecycle_transition_days = 30
    version_expiration_days = 365
    
    # CloudFront optimizations
    cloudfront_price_class = var.global_users ? "PriceClass_All" : "PriceClass_200"
    enable_logging = true
    enable_monitoring = true
    
    # Cognito optimizations
    advanced_security = true
    mfa_required = true
    
    # Monitoring optimizations
    detailed_monitoring = true
    log_retention_days = 90
    enable_alarms = true
  }
}
```

**Production Cost Breakdown (100 users):**
- S3 Storage: $2.00/month (50MB static + 1GB content)
- CloudFront: $1.50/month (moderate traffic)
- Route53: $0.50/month (hosted zone)
- Cognito: $0.00/month (under 50k users)
- Monitoring: $3.00/month (logs, alarms, metrics)
- **Total: ~$7.00/month**

## Cost Monitoring and Alerting

### 1. AWS Budgets Configuration

```hcl
resource "aws_budgets_budget" "infrastructure_budget" {
  name         = "${var.environment}-infrastructure-budget"
  budget_type  = "COST"
  limit_amount = var.environment == "prod" ? "25" : "10"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  
  cost_filters = {
    Service = [
      "Amazon Simple Storage Service",
      "Amazon CloudFront",
      "Amazon Cognito",
      "Amazon Route 53"
    ]
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}
```

### 2. CloudWatch Cost Alarms

```hcl
resource "aws_cloudwatch_metric_alarm" "high_s3_costs" {
  alarm_name          = "${var.environment}-high-s3-costs"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"  # Daily
  statistic           = "Maximum"
  threshold           = var.environment == "prod" ? "10" : "5"
  alarm_description   = "This metric monitors S3 costs"
  
  dimensions = {
    Currency    = "USD"
    ServiceName = "AmazonS3"
  }
  
  alarm_actions = [aws_sns_topic.cost_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "high_cloudfront_costs" {
  alarm_name          = "${var.environment}-high-cloudfront-costs"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"
  statistic           = "Maximum"
  threshold           = var.environment == "prod" ? "15" : "3"
  
  dimensions = {
    Currency    = "USD"
    ServiceName = "AmazonCloudFront"
  }
  
  alarm_actions = [aws_sns_topic.cost_alerts.arn]
}
```

### 3. Cost Anomaly Detection

```hcl
resource "aws_ce_anomaly_detector" "infrastructure_anomaly" {
  name         = "${var.environment}-infrastructure-anomaly"
  monitor_type = "DIMENSIONAL"
  
  specification = jsonencode({
    Dimension = "SERVICE"
    MatchOptions = ["EQUALS"]
    Values = [
      "Amazon Simple Storage Service",
      "Amazon CloudFront",
      "Amazon Cognito",
      "Amazon Route 53"
    ]
  })
}

resource "aws_ce_anomaly_subscription" "infrastructure_anomaly_subscription" {
  name      = "${var.environment}-infrastructure-anomaly-subscription"
  frequency = "DAILY"
  
  monitor_arn_list = [
    aws_ce_anomaly_detector.infrastructure_anomaly.arn
  ]
  
  subscriber {
    type    = "EMAIL"
    address = var.alert_email
  }
  
  threshold_expression {
    and {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
        values        = [var.environment == "prod" ? "10" : "5"]
        match_options = ["GREATER_THAN_OR_EQUAL"]
      }
    }
  }
}
```

## Cost Monitoring Procedures

### 1. Daily Monitoring Tasks

```bash
#!/bin/bash
# daily-cost-check.sh

echo "=== Daily Cost Monitoring Report ==="
echo "Date: $(date)"
echo

# Get current month costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --query 'ResultsByTime[0].Groups[?Metrics.BlendedCost.Amount>`0`].[Keys[0],Metrics.BlendedCost.Amount]' \
  --output table

# Check for cost anomalies
aws ce get-anomalies \
  --date-interval Start=$(date -d "7 days ago" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --query 'Anomalies[?Impact.TotalImpact>`5`].[AnomalyId,Impact.TotalImpact,RootCauses[0].Service]' \
  --output table

echo
echo "=== Budget Status ==="
aws budgets describe-budgets --account-id $(aws sts get-caller-identity --query Account --output text) \
  --query 'Budgets[?BudgetName==`infrastructure-budget`].[BudgetName,BudgetLimit.Amount,CalculatedSpend.ActualSpend.Amount]' \
  --output table
```

### 2. Weekly Cost Analysis

```bash
#!/bin/bash
# weekly-cost-analysis.sh

echo "=== Weekly Cost Analysis ==="
echo "Week ending: $(date)"
echo

# Get weekly cost trends
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "4 weeks ago" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity WEEKLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --query 'ResultsByTime[].[TimePeriod.Start,Groups[?Keys[0]==`Amazon Simple Storage Service`].Metrics.BlendedCost.Amount|[0],Groups[?Keys[0]==`Amazon CloudFront`].Metrics.BlendedCost.Amount|[0]]' \
  --output table

# Identify cost optimization opportunities
echo
echo "=== Optimization Opportunities ==="

# Check S3 storage class distribution
aws s3api list-objects-v2 --bucket your-bucket-name \
  --query 'Contents[?StorageClass!=`STANDARD`] | length(@)' \
  --output text | xargs -I {} echo "Objects in optimized storage classes: {}"

# Check CloudFront cache hit ratio
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name CacheHitRate \
  --dimensions Name=DistributionId,Value=YOUR_DISTRIBUTION_ID \
  --start-time $(date -d "7 days ago" --iso-8601) \
  --end-time $(date --iso-8601) \
  --period 86400 \
  --statistics Average \
  --query 'Datapoints[0].Average' \
  --output text | xargs -I {} echo "CloudFront cache hit ratio: {}%"
```

### 3. Monthly Cost Review

```bash
#!/bin/bash
# monthly-cost-review.sh

echo "=== Monthly Cost Review ==="
echo "Month: $(date +%Y-%m)"
echo

# Get detailed cost breakdown
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost,UsageQuantity \
  --group-by Type=DIMENSION,Key=SERVICE \
  --group-by Type=DIMENSION,Key=USAGE_TYPE \
  --output json > monthly-costs.json

# Generate cost report
python3 << EOF
import json
import sys

with open('monthly-costs.json', 'r') as f:
    data = json.load(f)

print("Service Costs:")
print("-" * 50)

for result in data['ResultsByTime']:
    for group in result['Groups']:
        service = group['Keys'][0]
        usage_type = group['Keys'][1]
        cost = float(group['Metrics']['BlendedCost']['Amount'])
        
        if cost > 0.01:  # Only show costs > $0.01
            print(f"{service:30} {usage_type:30} \${cost:8.2f}")

print("\nTop Cost Drivers:")
print("-" * 30)

# Sort by cost and show top 10
costs = []
for result in data['ResultsByTime']:
    for group in result['Groups']:
        cost = float(group['Metrics']['BlendedCost']['Amount'])
        if cost > 0:
            costs.append((group['Keys'][0], cost))

costs.sort(key=lambda x: x[1], reverse=True)
for service, cost in costs[:10]:
    print(f"{service:40} \${cost:8.2f}")
EOF

rm monthly-costs.json
```

## Cost Optimization Automation

### 1. Automated S3 Lifecycle Management

```python
#!/usr/bin/env python3
# s3-lifecycle-optimizer.py

import boto3
import json
from datetime import datetime, timedelta

def optimize_s3_lifecycle():
    s3 = boto3.client('s3')
    
    # Get all buckets
    buckets = s3.list_buckets()['Buckets']
    
    for bucket in buckets:
        bucket_name = bucket['Name']
        
        # Skip if not our infrastructure buckets
        if not any(x in bucket_name for x in ['website', 'content', 'tfstate']):
            continue
            
        print(f"Analyzing bucket: {bucket_name}")
        
        # Get current lifecycle configuration
        try:
            lifecycle = s3.get_bucket_lifecycle_configuration(Bucket=bucket_name)
            rules = lifecycle.get('Rules', [])
        except s3.exceptions.NoSuchLifecycleConfiguration:
            rules = []
        
        # Analyze object access patterns
        objects = s3.list_objects_v2(Bucket=bucket_name).get('Contents', [])
        
        old_objects = []
        for obj in objects:
            age = (datetime.now(obj['LastModified'].tzinfo) - obj['LastModified']).days
            if age > 30 and obj.get('StorageClass', 'STANDARD') == 'STANDARD':
                old_objects.append(obj)
        
        if old_objects:
            print(f"  Found {len(old_objects)} objects that could be moved to IA")
            
            # Suggest lifecycle rule
            suggested_rule = {
                'ID': f'auto-optimize-{datetime.now().strftime("%Y%m%d")}',
                'Status': 'Enabled',
                'Transitions': [
                    {
                        'Days': 30,
                        'StorageClass': 'STANDARD_IA'
                    },
                    {
                        'Days': 90,
                        'StorageClass': 'GLACIER'
                    }
                ]
            }
            
            print(f"  Suggested rule: {json.dumps(suggested_rule, indent=2)}")

if __name__ == "__main__":
    optimize_s3_lifecycle()
```

### 2. CloudFront Cache Optimization

```python
#!/usr/bin/env python3
# cloudfront-cache-optimizer.py

import boto3
from datetime import datetime, timedelta

def analyze_cloudfront_performance():
    cloudfront = boto3.client('cloudfront')
    cloudwatch = boto3.client('cloudwatch')
    
    # Get all distributions
    distributions = cloudfront.list_distributions()['DistributionList']['Items']
    
    for dist in distributions:
        dist_id = dist['Id']
        print(f"Analyzing distribution: {dist_id}")
        
        # Get cache hit ratio
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(days=7)
        
        response = cloudwatch.get_metric_statistics(
            Namespace='AWS/CloudFront',
            MetricName='CacheHitRate',
            Dimensions=[
                {
                    'Name': 'DistributionId',
                    'Value': dist_id
                }
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=86400,
            Statistics=['Average']
        )
        
        if response['Datapoints']:
            avg_hit_rate = sum(dp['Average'] for dp in response['Datapoints']) / len(response['Datapoints'])
            print(f"  Average cache hit rate: {avg_hit_rate:.2f}%")
            
            if avg_hit_rate < 80:
                print("  ⚠️  Low cache hit rate - consider optimizing cache behaviors")
                
                # Analyze cache behaviors
                config = cloudfront.get_distribution_config(Id=dist_id)
                behaviors = config['DistributionConfig'].get('CacheBehaviors', {}).get('Items', [])
                
                for behavior in behaviors:
                    print(f"    Path: {behavior['PathPattern']}")
                    print(f"    TTL: {behavior.get('DefaultTTL', 'Not set')}")
                    print(f"    Headers: {len(behavior.get('ForwardedValues', {}).get('Headers', {}).get('Items', []))}")
            else:
                print("  ✅ Good cache hit rate")

if __name__ == "__main__":
    analyze_cloudfront_performance()
```

## Cost Reporting and Dashboards

### 1. CloudWatch Dashboard Configuration

```hcl
resource "aws_cloudwatch_dashboard" "cost_dashboard" {
  dashboard_name = "${var.environment}-cost-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Billing", "EstimatedCharges", "Currency", "USD", "ServiceName", "AmazonS3"],
            [".", ".", ".", ".", ".", "AmazonCloudFront"],
            [".", ".", ".", ".", ".", "AmazonCognito"],
            [".", ".", ".", ".", ".", "AmazonRoute53"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Daily Estimated Charges by Service"
          period  = 86400
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 6
        height = 6

        properties = {
          metrics = [
            ["AWS/S3", "BucketSizeBytes", "BucketName", aws_s3_bucket.website.id, "StorageType", "StandardStorage"],
            [".", ".", ".", aws_s3_bucket.content.id, ".", "."]
          ]
          view   = "timeSeries"
          region = var.aws_region
          title  = "S3 Storage Usage"
          period = 86400
        }
      },
      {
        type   = "metric"
        x      = 6
        y      = 6
        width  = 6
        height = 6

        properties = {
          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId", aws_cloudfront_distribution.main.id],
            [".", "BytesDownloaded", ".", "."]
          ]
          view   = "timeSeries"
          region = "us-east-1"
          title  = "CloudFront Usage"
          period = 3600
        }
      }
    ]
  })
}
```

### 2. Cost Report Generation

```bash
#!/bin/bash
# generate-cost-report.sh

REPORT_DATE=$(date +%Y-%m-%d)
REPORT_FILE="cost-report-${REPORT_DATE}.html"

cat > $REPORT_FILE << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Infrastructure Cost Report - $REPORT_DATE</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .cost { text-align: right; }
        .alert { color: red; font-weight: bold; }
        .good { color: green; }
    </style>
</head>
<body>
    <h1>Infrastructure Cost Report</h1>
    <p>Generated: $REPORT_DATE</p>
    
    <h2>Current Month Costs</h2>
    <table>
        <tr><th>Service</th><th>Cost</th><th>Status</th></tr>
EOF

# Get current costs and add to report
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --query 'ResultsByTime[0].Groups[?Metrics.BlendedCost.Amount>`0`]' \
  --output json | jq -r '.[] | 
    "<tr><td>" + .Keys[0] + "</td><td class=\"cost\">$" + (.Metrics.BlendedCost.Amount | tonumber | . * 100 | round / 100 | tostring) + "</td><td>" + 
    (if (.Metrics.BlendedCost.Amount | tonumber) > 10 then "<span class=\"alert\">High</span>" 
     elif (.Metrics.BlendedCost.Amount | tonumber) < 1 then "<span class=\"good\">Low</span>" 
     else "Normal" end) + "</td></tr>"' >> $REPORT_FILE

cat >> $REPORT_FILE << EOF
    </table>
    
    <h2>Optimization Recommendations</h2>
    <ul>
EOF

# Add optimization recommendations
echo "        <li>Review S3 storage classes for objects older than 30 days</li>" >> $REPORT_FILE
echo "        <li>Check CloudFront cache hit ratios</li>" >> $REPORT_FILE
echo "        <li>Verify lifecycle policies are working correctly</li>" >> $REPORT_FILE

cat >> $REPORT_FILE << EOF
    </ul>
    
    <h2>Budget Status</h2>
EOF

# Add budget information
aws budgets describe-budgets --account-id $(aws sts get-caller-identity --query Account --output text) \
  --query 'Budgets[?BudgetName==`infrastructure-budget`]' \
  --output json | jq -r '.[0] | 
    "<p>Budget: $" + .BudgetLimit.Amount + " | Actual: $" + .CalculatedSpend.ActualSpend.Amount + " | Forecasted: $" + .CalculatedSpend.ForecastedSpend.Amount + "</p>"' >> $REPORT_FILE

cat >> $REPORT_FILE << EOF
</body>
</html>
EOF

echo "Cost report generated: $REPORT_FILE"
```

## Best Practices Summary

### 1. Proactive Cost Management
- Set up budgets and alerts before costs become an issue
- Review costs weekly, not just monthly
- Use cost anomaly detection for unusual spending patterns
- Tag all resources for proper cost allocation

### 2. Environment-Specific Strategies
- **Development**: Prioritize cost over performance
- **Production**: Balance cost with reliability and performance
- **Staging**: Use production-like settings but smaller scale

### 3. Automation
- Implement lifecycle policies for all storage
- Use scheduled scripts for cost analysis
- Automate cleanup of unused resources
- Set up automatic scaling based on usage

### 4. Regular Reviews
- Monthly cost reviews with stakeholders
- Quarterly optimization assessments
- Annual architecture reviews for cost efficiency
- Continuous monitoring of new AWS cost optimization features

This comprehensive cost optimization guide ensures that your infrastructure remains cost-effective while maintaining the required performance and security standards.