module "ctx" {
  source = "../platform-context"
}

locals {
  security_group_ids = var.vpn_access ? [
    module.ctx.platform_lambda_sg_id,
    module.ctx.vpn_client_sg_id
  ] : [module.ctx.platform_lambda_sg_id]
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
  memory_size   = 256

  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256

  vpc_config {
    subnet_ids         = module.ctx.private_subnet_ids
    security_group_ids = local.security_group_ids
  }

  dynamic "environment" {
    for_each = length(var.environment) > 0 ? [1] : []
    content {
      variables = var.environment
    }
  }

  depends_on = [aws_cloudwatch_log_group.this]
}
