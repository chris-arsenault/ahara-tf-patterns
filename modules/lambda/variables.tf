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

variable "vpc" {
  description = "VPC context, typically from platform-context.vpc output. Consumers call platform-context once and forward this to every lambda/alb-api/website call."
  type = object({
    private_subnet_ids = list(string)
    lambda_sg_id       = string
    vpn_client_sg_id   = string
  })
}
