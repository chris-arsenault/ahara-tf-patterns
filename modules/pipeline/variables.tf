variable "prefix" {
  description = "Registered project prefix"
  type        = string
}
variable "name" {
  description = "Pipeline name within the project"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.name))
    error_message = "Use a lowercase kebab-case pipeline name."
  }
}
variable "description" { type = string }
variable "owner" {
  description = "Owning repository"
  type        = string
}
variable "definition" {
  description = "Native Amazon States Language JSON; processing belongs to the client"
  type        = string
  validation {
    condition     = can(jsondecode(var.definition).StartAt) && can(jsondecode(var.definition).States)
    error_message = "Supply a native state machine with StartAt and States."
  }
}
variable "lambda_function_arns" {
  description = "Worker functions the execution role may invoke"
  type        = set(string)
}
variable "schedule_expression" { type = string }
variable "timezone" {
  type    = string
  default = "UTC"
}
variable "enabled" {
  type    = bool
  default = false
}
variable "input" {
  description = "Scheduled execution input, including any Scheduler context attributes"
  type        = any
  default     = {}
}
variable "platform" {
  description = "Shared pipeline context; no workflow resources are centrally owned"
  type = object({
    registry_table_name = string
    registry_table_arn  = string
    alarm_topic_arn     = string
  })
}
