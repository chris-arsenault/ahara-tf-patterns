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

variable "vpn_access" {
  description = "Attach VPN client security group for TrueNAS/WireGuard network access"
  type        = bool
  default     = false
}
