variable "hostname" {
  description = "Custom domain for the API (e.g. api.tastebase.ahara.io)"
  type        = string
}

variable "lambdas" {
  description = "Map of Lambda function name suffix → configuration"
  type = map(object({
    zip = string
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
  description = "IAM policy JSON for additional permissions beyond basic execution and VPC access"
  type        = string
  default     = null
}
