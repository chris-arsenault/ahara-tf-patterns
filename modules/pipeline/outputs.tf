output "workflow_arn" { value = aws_sfn_state_machine.this.arn }
output "schedule_arn" { value = aws_scheduler_schedule.this.arn }
output "delivery_queue_url" { value = aws_sqs_queue.delivery.url }
