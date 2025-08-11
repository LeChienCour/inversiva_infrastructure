# Monitoring and Alerting Module
# This module creates CloudWatch dashboards, cost alerts, security monitoring, and performance monitoring

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources for existing resources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"

  tags = {
    Name        = "${var.project_name}-${var.environment}-alerts"
    Environment = var.environment
    Project     = var.project_name
  }
}

# SNS Topic subscription for email alerts
resource "aws_sns_topic_subscription" "email_alerts" {
  count     = length(var.alert_email_addresses)
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email_addresses[count.index]
}

# CloudWatch Dashboard for Infrastructure Monitoring (only if enabled)
resource "aws_cloudwatch_dashboard" "infrastructure" {
  count          = var.enable_dashboard ? 1 : 0
  dashboard_name = "${var.project_name}-${var.environment}-infrastructure"

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
            ["AWS/CloudFront", "Requests", "DistributionId", var.cloudfront_distribution_id],
            [".", "4xxErrorRate", ".", "."],
            [".", "5xxErrorRate", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "CloudFront Request Metrics"
          period  = 3600
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/CloudFront", "CacheHitRate", "DistributionId", var.cloudfront_distribution_id],
            [".", "OriginLatency", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "CloudFront Performance"
          period  = 3600
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/S3", "BucketSizeBytes", "BucketName", var.website_bucket_name, "StorageType", "StandardStorage"],
            [".", ".", var.content_bucket_name, ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "S3 Storage Usage"
          period  = 86400  # Daily
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/S3", "NumberOfObjects", "BucketName", var.website_bucket_name, "StorageType", "AllStorageTypes"],
            [".", ".", var.content_bucket_name, ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "S3 Object Count"
          period  = 86400  # Daily
        }
      }
    ]
  })
}

# Cost Budget for monitoring spending
resource "aws_budgets_budget" "cost_budget" {
  name         = "${var.project_name}-${var.environment}-budget"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  time_period_start = formatdate("YYYY-MM-01_00:00", timestamp())

  cost_filters = {
    Tag = [
      "Environment:${var.environment}",
      "Project:${var.project_name}"
    ]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = var.alert_email_addresses
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.alert_email_addresses
  }
}

# CloudTrail for security monitoring
resource "aws_cloudtrail" "security_trail" {
  count                         = var.enable_cloudtrail ? 1 : 0
  name                          = "${var.project_name}-${var.environment}-security-trail"
  s3_bucket_name               = aws_s3_bucket.cloudtrail_logs[0].bucket
  cloud_watch_logs_group_arn   = "${aws_cloudwatch_log_group.cloudtrail_log_group[0].arn}:*"
  cloud_watch_logs_role_arn    = aws_iam_role.cloudtrail_logs_role[0].arn
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_logging               = true

  event_selector {
    read_write_type                 = "All"
    include_management_events       = true
    exclude_management_event_sources = []

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${var.website_bucket_arn}/*", "${var.content_bucket_arn}/*"]
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-security-trail"
    Environment = var.environment
    Project     = var.project_name
  }
}

# S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "cloudtrail_logs" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = "${var.project_name}-${var.environment}-cloudtrail-logs-${random_id.cloudtrail_suffix[0].hex}"

  tags = {
    Name        = "${var.project_name}-${var.environment}-cloudtrail-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "random_id" "cloudtrail_suffix" {
  count       = var.enable_cloudtrail ? 1 : 0
  byte_length = 4
}

# CloudTrail S3 bucket policy
resource "aws_s3_bucket_policy" "cloudtrail_logs_policy" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs[0].arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs[0].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# CloudTrail S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs_encryption" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# CloudTrail S3 bucket versioning
resource "aws_s3_bucket_versioning" "cloudtrail_logs_versioning" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail_logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# CloudWatch Alarms for Security Monitoring
resource "aws_cloudwatch_log_metric_filter" "unauthorized_api_calls" {
  count          = var.enable_cloudtrail ? 1 : 0
  name           = "${var.project_name}-${var.environment}-unauthorized-api-calls"
  log_group_name = aws_cloudwatch_log_group.cloudtrail_log_group[0].name
  pattern        = "{ ($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\") }"

  metric_transformation {
    name      = "UnauthorizedAPICalls"
    namespace = "${var.project_name}/${var.environment}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_group" "cloudtrail_log_group" {
  count             = var.enable_cloudtrail ? 1 : 0
  name              = "/aws/cloudtrail/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-${var.environment}-cloudtrail-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM role for CloudTrail to write to CloudWatch Logs
resource "aws_iam_role" "cloudtrail_logs_role" {
  count = var.enable_cloudtrail ? 1 : 0
  name  = "${var.project_name}-${var.environment}-cloudtrail-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-cloudtrail-logs-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM policy for CloudTrail to write to CloudWatch Logs
resource "aws_iam_role_policy" "cloudtrail_logs_policy" {
  count = var.enable_cloudtrail ? 1 : 0
  name  = "${var.project_name}-${var.environment}-cloudtrail-logs-policy"
  role  = aws_iam_role.cloudtrail_logs_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail_log_group[0].arn}:*"
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls_alarm" {
  count               = var.enable_cloudtrail ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-unauthorized-api-calls"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnauthorizedAPICalls"
  namespace           = "${var.project_name}/${var.environment}/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This metric monitors unauthorized API calls"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  tags = {
    Name        = "${var.project_name}-${var.environment}-unauthorized-api-calls-alarm"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Essential Performance Monitoring Alarms (only critical ones)
resource "aws_cloudwatch_metric_alarm" "cloudfront_error_rate" {
  count               = var.enable_performance_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-cloudfront-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"  # Longer evaluation to reduce false positives
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = "900"  # 15 minutes instead of 5 to reduce costs
  statistic           = "Average"
  threshold           = "10"   # Higher threshold to reduce noise
  alarm_description   = "Critical CloudFront error rate monitoring"
  alarm_actions       = var.enable_sns_alerts ? [aws_sns_topic.alerts.arn] : []
  treat_missing_data  = "notBreaching"  # Don't alarm on missing data

  dimensions = {
    DistributionId = var.cloudfront_distribution_id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-cloudfront-error-rate"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Cost monitoring alarm
resource "aws_cloudwatch_metric_alarm" "high_cost_alert" {
  count               = var.enable_cost_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-high-cost"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"  # Daily check
  statistic           = "Maximum"
  threshold           = var.cost_alarm_threshold
  alarm_description   = "Daily cost monitoring alarm"
  alarm_actions       = var.enable_sns_alerts ? [aws_sns_topic.alerts.arn] : []
  treat_missing_data  = "notBreaching"

  dimensions = {
    Currency = "USD"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-high-cost"
    Environment = var.environment
    Project     = var.project_name
  }
}

# S3 4xx Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "s3_4xx_errors" {
  count               = var.enable_performance_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-s3-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4xxErrors"
  namespace           = "AWS/S3"
  period              = "900"  # 15 minutes
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "S3 4xx error rate monitoring"
  alarm_actions       = var.enable_sns_alerts ? [aws_sns_topic.alerts.arn] : []
  treat_missing_data  = "notBreaching"

  dimensions = {
    BucketName = var.website_bucket_name
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-s3-4xx-errors"
    Environment = var.environment
    Project     = var.project_name
  }
}

# CloudFront Cache Hit Rate Alarm (low cache hit rate indicates potential performance issues)
resource "aws_cloudwatch_metric_alarm" "cloudfront_cache_hit_rate" {
  count               = var.enable_performance_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-cloudfront-cache-hit-rate"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CacheHitRate"
  namespace           = "AWS/CloudFront"
  period              = "900"  # 15 minutes
  statistic           = "Average"
  threshold           = "80"   # Alert if cache hit rate drops below 80%
  alarm_description   = "CloudFront cache hit rate monitoring"
  alarm_actions       = var.enable_sns_alerts ? [aws_sns_topic.alerts.arn] : []
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = var.cloudfront_distribution_id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-cloudfront-cache-hit-rate"
    Environment = var.environment
    Project     = var.project_name
  }
}