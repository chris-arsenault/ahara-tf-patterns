variable "name" {
  description = "Lambda function name"
  type        = string
}

variable "binary" {
  description = "Path to the bootstrap binary (will be zipped automatically)"
  type        = string
  default     = null
  validation {
    condition     = (var.binary != null) != (var.package_file != null)
    error_message = "Supply exactly one binary or package_file."
  }
}

variable "package_file" {
  description = "Optional prebuilt ZIP containing the handler and dependencies."
  type        = string
  default     = null
}
variable "runtime" {
  description = "Lambda runtime; existing binary callers use provided.al2023."
  type        = string
  default     = "provided.al2023"
}
variable "handler" {
  description = "Handler within a ZIP package."
  type        = string
  default     = "bootstrap"
}

variable "ephemeral_storage" {
  description = "Lambda scratch storage in MB."
  type        = number
  default     = 512
  validation {
    condition     = var.ephemeral_storage >= 512 && var.ephemeral_storage <= 10240
    error_message = "Lambda scratch storage must be between 512 and 10240 MB."
  }
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

variable "memory_size" {
  description = "Lambda memory in MB"
  type        = number
  default     = 256
}

variable "reserved_concurrent_executions" {
  description = "Optional reserved concurrency cap for the Lambda. Null leaves the AWS account default behavior unchanged."
  type        = number
  default     = null
}

variable "layers" {
  description = "Optional Lambda layer ARNs, for example ADOT or vendor OpenTelemetry collector layers."
  type        = list(string)
  default     = []
}

variable "tracing_mode" {
  description = "Optional Lambda tracing mode. Use Active to enable AWS X-Ray tracing."
  type        = string
  default     = null

  validation {
    condition     = var.tracing_mode == null || contains(["Active", "PassThrough"], var.tracing_mode)
    error_message = "tracing_mode must be null, Active, or PassThrough."
  }
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
