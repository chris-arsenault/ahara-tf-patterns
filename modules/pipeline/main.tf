data "aws_caller_identity" "this" {}
data "aws_region" "this" {}
locals {
  name         = "${var.prefix}-pipeline-${var.name}"
  workflow_arn = "arn:aws:states:${data.aws_region.this.region}:${data.aws_caller_identity.this.account_id}:stateMachine:${local.name}"
  group_arn    = "arn:aws:scheduler:${data.aws_region.this.region}:${data.aws_caller_identity.this.account_id}:schedule-group/${local.name}"
}
data "aws_iam_policy_document" "workflow_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.this.account_id]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [local.workflow_arn]
    }
  }
}
resource "aws_iam_role" "workflow" {
  name               = local.name
  assume_role_policy = data.aws_iam_policy_document.workflow_trust.json
}
resource "aws_iam_role_policy" "workers" {
  count = length(var.lambda_function_arns) > 0 ? 1 : 0
  role  = aws_iam_role.workflow.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["lambda:InvokeFunction"], Resource = sort(tolist(var.lambda_function_arns)) }]
  })
}
resource "aws_sfn_state_machine" "this" {
  name       = local.name
  role_arn   = aws_iam_role.workflow.arn
  type       = "STANDARD"
  definition = var.definition
  tags       = { Project = var.prefix, Pipeline = var.name }
  depends_on = [aws_iam_role_policy.workers]
}
resource "aws_scheduler_schedule_group" "this" { name = local.name }
resource "aws_sqs_queue" "delivery" {
  name                      = "${local.name}-delivery"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}
resource "aws_cloudwatch_metric_alarm" "delivery" {
  alarm_name          = "${local.name}-delivery"
  alarm_description   = "Scheduler exhausted delivery retries; inspect the pipeline DLQ."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.delivery.name }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.platform.alarm_topic_arn]
}
data "aws_iam_policy_document" "schedule_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.this.account_id]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [local.group_arn]
    }
  }
}
resource "aws_iam_role" "schedule" {
  name               = "${local.name}-schedule"
  assume_role_policy = data.aws_iam_policy_document.schedule_trust.json
}
resource "aws_iam_role_policy" "schedule" {
  role = aws_iam_role.schedule.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["states:StartExecution"], Resource = aws_sfn_state_machine.this.arn },
      { Effect = "Allow", Action = ["sqs:SendMessage"], Resource = aws_sqs_queue.delivery.arn },
    ]
  })
}
resource "aws_scheduler_schedule" "this" {
  name                         = local.name
  group_name                   = aws_scheduler_schedule_group.this.name
  schedule_expression          = var.schedule_expression
  schedule_expression_timezone = var.timezone
  state                        = var.enabled ? "ENABLED" : "DISABLED"
  flexible_time_window { mode = "OFF" }
  target {
    arn      = aws_sfn_state_machine.this.arn
    role_arn = aws_iam_role.schedule.arn
    input    = jsonencode(var.input)
    dead_letter_config { arn = aws_sqs_queue.delivery.arn }
    retry_policy {
      maximum_event_age_in_seconds = 3600
      maximum_retry_attempts       = 3
    }
  }
  depends_on = [aws_iam_role_policy.schedule, aws_dynamodb_table_item.registration]
}
resource "aws_dynamodb_table_item" "registration" {
  table_name = var.platform.registry_table_name
  hash_key   = "workflow_arn"
  item = jsonencode({
    workflow_arn = { S = aws_sfn_state_machine.this.arn }
    project      = { S = var.prefix }
    pipeline     = { S = var.name }
    description  = { S = var.description }
    owner        = { S = var.owner }
    schedule     = { S = var.schedule_expression }
    timezone     = { S = var.timezone }
    enabled      = { BOOL = var.enabled }
  })
}
