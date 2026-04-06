locals {
  has_vpc = length(var.subnet_ids) > 0
}

data "archive_file" "this" {
  type        = "zip"
  source_file = var.binary
  output_path = "${var.binary}.zip"
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = 14
}

resource "aws_lambda_function" "this" {
  function_name = var.name
  role          = var.role_arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  architectures = ["x86_64"]
  timeout       = var.timeout
  memory_size   = var.memory

  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256

  dynamic "vpc_config" {
    for_each = local.has_vpc ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  dynamic "environment" {
    for_each = length(var.environment) > 0 ? [1] : []
    content {
      variables = var.environment
    }
  }

  depends_on = [aws_cloudwatch_log_group.this]
}
