variable "lambda_zip_path" {
  type    = string
  default = "../build/ddrc-lambda.zip"
}

variable "enable_sqs" {
  description = "Feature toggle: true routes /validate through SQS, false validates inline"
  type        = bool
  default     = false
}

# ---------- results table ----------

resource "aws_dynamodb_table" "results" {
  name         = "ddrc-results"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "request_id"

  attribute {
    name = "request_id"
    type = "S"
  }
}

# ---------- queues ----------

resource "aws_sqs_queue" "validation_dlq" {
  name = "ddrc-validation-dlq"
}

resource "aws_sqs_queue" "validation" {
  name                       = "ddrc-validation"
  visibility_timeout_seconds = 60

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.validation_dlq.arn
    maxReceiveCount     = 3
  })
}

# ---------- IAM: one least-privilege role per function ----------

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api" {
  name               = "ddrc-api-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy" "api" {
  name = "ddrc-api-lambda"
  role = aws_iam_role.api.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "WriteOwnLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.api.arn}:*"
      },
      {
        Sid      = "EnqueueValidations"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.validation.arn
      },
      {
        Sid      = "StoreResults"
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = aws_dynamodb_table.results.arn
      }
    ]
  })
}

resource "aws_iam_role" "worker" {
  name               = "ddrc-worker-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy" "worker" {
  name = "ddrc-worker-lambda"
  role = aws_iam_role.worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "WriteOwnLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.worker.arn}:*"
      },
      {
        Sid    = "ConsumeQueue"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.validation.arn
      },
      {
        Sid      = "StoreResults"
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = aws_dynamodb_table.results.arn
      }
    ]
  })
}

# ---------- log groups (created by us, with retention) ----------

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/lambda/ddrc-api"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/aws/lambda/ddrc-worker"
  retention_in_days = 14
}

# ---------- the two functions ----------

resource "aws_lambda_function" "api" {
  function_name    = "ddrc-api"
  role             = aws_iam_role.api.arn
  runtime          = "python3.12"
  handler          = "src.handlers.api.handler"
  filename         = var.lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda_zip_path)
  timeout          = 10

  environment {
    variables = {
      ENABLE_SQS = tostring(var.enable_sqs)
      QUEUE_URL  = aws_sqs_queue.validation.url
      TABLE_NAME = aws_dynamodb_table.results.name
    }
  }

  depends_on = [aws_cloudwatch_log_group.api]
}

resource "aws_lambda_function" "worker" {
  function_name    = "ddrc-worker"
  role             = aws_iam_role.worker.arn
  runtime          = "python3.12"
  handler          = "src.handlers.worker.handler"
  filename         = var.lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda_zip_path)
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.results.name
    }
  }

  depends_on = [aws_cloudwatch_log_group.worker]
}

resource "aws_lambda_event_source_mapping" "worker_queue" {
  event_source_arn = aws_sqs_queue.validation.arn
  function_name    = aws_lambda_function.worker.arn
  batch_size       = 5
}

# ---------- API Gateway front door ----------

resource "aws_apigatewayv2_api" "ddrc" {
  name          = "ddrc-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "api_lambda" {
  api_id                 = aws_apigatewayv2_api.ddrc.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "validate" {
  api_id    = aws_apigatewayv2_api.ddrc.id
  route_key = "POST /validate"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.ddrc.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.ddrc.execution_arn}/*/*"
}

# ---------- outputs ----------

output "api_endpoint" {
  value = aws_apigatewayv2_api.ddrc.api_endpoint
}

output "queue_url" {
  value = aws_sqs_queue.validation.url
}

output "dlq_url" {
  value = aws_sqs_queue.validation_dlq.url
}

output "table_name" {
  value = aws_dynamodb_table.results.name
}

output "function_arns" {
  value = [aws_lambda_function.api.arn, aws_lambda_function.worker.arn]
}
