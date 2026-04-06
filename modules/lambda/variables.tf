variable "name" {
  description = "Lambda function name"
  type        = string
}

variable "zip" {
  description = "Path to the Lambda deployment zip"
  type        = string
}

variable "role_arn" {
  description = "IAM role ARN for the Lambda"
  type        = string
}

variable "subnet_ids" {
  description = "VPC subnet IDs"
  type        = list(string)
}

variable "security_group_ids" {
  description = "VPC security group IDs"
  type        = list(string)
}

variable "environment" {
  description = "Environment variables"
  type        = map(string)
  default     = {}
}
