variable "alert_email" {
  description = "Email address subscribed to DDRC alarm notifications"
  type        = string
}

# ---------- notifications ----------

resource "aws_sns_topic" "alerts" {
  name = "ddrc-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ---------- alarms ----------

resource "aws_cloudwatch_metric_alarm" "worker_errors" {
  alarm_name          = "ddrc-worker-errors"
  alarm_description   = "The DDRC worker Lambda is failing"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = aws_lambda_function.worker.function_name }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "dlq_depth" {
  alarm_name          = "ddrc-dlq-messages"
  alarm_description   = "Messages have landed in the DDRC dead letter queue"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.validation_dlq.name }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

# ---------- dashboard ----------

resource "aws_cloudwatch_dashboard" "ddrc" {
  dashboard_name = "ddrc-module5"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "Lambda invocations and errors"
          region = "us-west-2"
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.api.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.worker.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.api.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.worker.function_name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "Queue depths"
          region = "us-west-2"
          stat   = "Maximum"
          period = 60
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.validation.name],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.validation_dlq.name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "API requests and errors"
          region = "us-west-2"
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiId", aws_apigatewayv2_api.ddrc.id],
            ["AWS/ApiGateway", "4xx", "ApiId", aws_apigatewayv2_api.ddrc.id],
            ["AWS/ApiGateway", "5xx", "ApiId", aws_apigatewayv2_api.ddrc.id]
          ]
        }
      }
    ]
  })
}

# ---------- saved Logs Insights trace query ----------

resource "aws_cloudwatch_query_definition" "trace_request" {
  name = "ddrc-trace-by-request-id"

  log_group_names = [
    aws_cloudwatch_log_group.api.name,
    aws_cloudwatch_log_group.worker.name
  ]

  query_string = <<-EOT
    fields @timestamp, @log, @message
    | filter @message like "PASTE-REQUEST-ID-HERE"
    | sort @timestamp asc
  EOT
}
