variable "prefix" {
  description = "Project resource prefix (must match the deployer IAM scope, e.g. 'tastebase')"
  type        = string
}

variable "hostname" {
  description = "Custom domain for the API (e.g. api.tastebase.ahara.io)"
  type        = string
}

variable "zone_name" {
  description = "Route53 zone name. Defaults to the last two labels of hostname. Override for delegated subzones or multi-label TLDs."
  type        = string
  default     = null
}

variable "lambdas" {
  description = "Map of Lambda function name suffix → configuration"
  type = map(object({
    binary = string
    routes = list(object({
      priority      = number
      paths         = list(string)
      methods       = optional(list(string))
      authenticated = optional(bool, true)
    }))
    environment = optional(map(string), {})
  }))
}

variable "environment" {
  description = "Environment variables shared across all Lambdas"
  type        = map(string)
  default     = {}
}

variable "iam_policy" {
  description = "Optional inline IAM policy JSON for additional permissions beyond basic execution and VPC access. Wrap a single policy in a list: [jsonencode(...)] or [data.x.json]. Empty list = no inline policy."
  type        = list(string)
  default     = []
}

variable "vpc" {
  description = "VPC context, typically from platform-context.vpc. Forwarded to the internal lambda module."
  type = object({
    private_subnet_ids = list(string)
    lambda_sg_id       = string
    vpn_client_sg_id   = string
  })
}

variable "alb" {
  description = "ALB context, typically from platform-context.alb. Used to attach listener rules and DNS alias records. arn is optional (unused by this module, retained for consistency with platform-context's grouped output)."
  type = object({
    arn          = optional(string)
    dns_name     = string
    zone_id      = string
    listener_arn = string
  })
}

variable "cognito" {
  description = "Cognito context, required only when one or more routes have authenticated = true. Typically from platform-context.cognito."
  type = object({
    issuer = string
    jwks   = string
  })
  default = null
}
