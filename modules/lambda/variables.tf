variable "name" {
  description = "Lambda function name"
  type        = string
}

variable "binary" {
  description = "Path to the bootstrap binary (will be zipped automatically)"
  type        = string
}

variable "role_arn" {
  description = "IAM role ARN for the Lambda"
  type        = string
}

variable "subnet_ids" {
  description = "VPC subnet IDs. Omit for Lambdas that don't need VPC access."
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "VPC security group IDs. Omit for Lambdas that don't need VPC access."
  type        = list(string)
  default     = []
}

variable "environment" {
  description = "Environment variables"
  type        = map(string)
  default     = {}
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "memory" {
  description = "Lambda memory in MB"
  type        = number
  default     = 256
}
