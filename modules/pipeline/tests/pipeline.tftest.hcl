mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "559098897826" }
  }
  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }
}
variables {
  prefix               = "atlas"
  name                 = "languages"
  owner                = "chris-arsenault/atlas"
  description          = "Language data"
  definition           = "{\"StartAt\":\"Done\",\"States\":{\"Done\":{\"Type\":\"Pass\",\"End\":true}}}"
  lambda_function_arns = ["arn:aws:lambda:us-east-1:559098897826:function:atlas-worker"]
  schedule_expression  = "rate(7 days)"
  platform = {
    registry_table_name = "ahara-pipeline-registry"
    registry_table_arn  = "arn:aws:dynamodb:us-east-1:559098897826:table/ahara-pipeline-registry"
    alarm_topic_arn     = "arn:aws:sns:us-east-1:559098897826:ahara-alarms"
  }
}
run "client_owned_pipeline" {
  command = plan
  assert {
    condition     = aws_sfn_state_machine.this.type == "STANDARD" && aws_sfn_state_machine.this.definition == var.definition
    error_message = "Preserve the client's native Standard workflow."
  }
  assert {
    condition     = aws_scheduler_schedule.this.state == "DISABLED" && aws_dynamodb_table_item.registration.table_name == var.platform.registry_table_name
    error_message = "Register in the shared table and default to disabled scheduling."
  }
  assert {
    condition     = toset(jsondecode(aws_iam_role_policy.workers[0].policy).Statement[0].Resource) == var.lambda_function_arns
    error_message = "Only declared workers may be invoked."
  }
}
run "enabled_schedule" {
  command = plan
  variables { enabled = true }
  assert {
    condition     = aws_scheduler_schedule.this.state == "ENABLED"
    error_message = "Respect the client's schedule state."
  }
}
