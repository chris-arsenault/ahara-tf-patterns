variable "prefix" {
  description = "Project resource prefix (must match the deployer IAM scope, e.g. 'tastebase')"
  type        = string
}

variable "hostname" {
  description = "Custom domain for the API (e.g. api.tastebase.ahara.io)"
  type        = string
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
