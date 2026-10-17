locals {
  security_group_ids = var.vpn_access ? [
    var.vpc.lambda_sg_id,
    var.vpc.vpn_client_sg_id,
  ] : [var.vpc.lambda_sg_id]
}

data "archive_file" "this" {
  count       = var.binary != null ? 1 : 0
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
  handler       = var.handler
  runtime       = var.runtime
  architectures = ["x86_64"]
  timeout       = var.timeout
  memory_size   = var.memory_size
  layers        = var.layers

  reserved_concurrent_executions = var.reserved_concurrent_executions

  filename         = var.package_file != null ? var.package_file : data.archive_file.this[0].output_path
  source_code_hash = var.package_file != null ? filebase64sha256(var.package_file) : data.archive_file.this[0].output_base64sha256

  ephemeral_storage { size = var.ephemeral_storage }

  vpc_config {
    subnet_ids         = var.vpc.private_subnet_ids
    security_group_ids = local.security_group_ids
  }

  dynamic "environment" {
    for_each = length(var.environment) > 0 ? [1] : []
    content {
      variables = var.environment
    }
  }

  dynamic "tracing_config" {
    for_each = var.tracing_mode == null ? [] : [var.tracing_mode]
    content {
      mode = tracing_config.value
    }
  }

  depends_on = [aws_cloudwatch_log_group.this]
}
