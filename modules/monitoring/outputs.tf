# Outputs for Monitoring Module

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = var.enable_dashboard ? "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.infrastructure[0].dashboard_name}" : "Dashboard disabled for cost optimization"
}

output "budget_name" {
  description = "Name of the cost budget"
  value       = length(var.alert_email_addresses) > 0 ? aws_budgets_budget.cost_budget[0].name : null
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = var.enable_cloudtrail ? aws_cloudtrail.security_trail[0].arn : null
}

output "cloudtrail_bucket_name" {
  description = "Name of the CloudTrail S3 bucket"
  value       = var.enable_cloudtrail ? aws_s3_bucket.cloudtrail_logs[0].bucket : null
}

output "log_group_name" {
  description = "Name of the CloudTrail log group"
  value       = var.enable_cloudtrail ? aws_cloudwatch_log_group.cloudtrail_log_group[0].name : null
}

output "alarm_names" {
  description = "List of CloudWatch alarm names"
  value = compact([
    var.enable_performance_alarms ? aws_cloudwatch_metric_alarm.cloudfront_error_rate[0].alarm_name : null,
    var.enable_performance_alarms ? aws_cloudwatch_metric_alarm.s3_4xx_errors[0].alarm_name : null,
    var.enable_performance_alarms ? aws_cloudwatch_metric_alarm.cloudfront_cache_hit_rate[0].alarm_name : null,
    var.enable_cost_alarms ? aws_cloudwatch_metric_alarm.high_cost_alert[0].alarm_name : null,
    var.enable_cloudtrail ? aws_cloudwatch_metric_alarm.unauthorized_api_calls_alarm[0].alarm_name : null
  ])
}