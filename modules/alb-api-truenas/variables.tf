variable "hostname" {
  description = "Custom domain for the TrueNAS-backed API/app"
  type        = string
}

variable "zone_name" {
  description = "Route53 zone name. Defaults to the last two labels of hostname. Override for delegated subzones or multi-label TLDs."
  type        = string
  default     = null
}

variable "routes" {
  description = "ALB listener routes forwarded to the TrueNAS/reverse-proxy target group"
  type = list(object({
    priority      = number
    paths         = list(string)
    methods       = optional(list(string))
    authenticated = optional(bool, true)
  }))
}

variable "target_group_arn" {
  description = "Existing ALB target group ARN for the TrueNAS/reverse-proxy target"
  type        = string
}

variable "alb" {
  description = "ALB context, typically from platform-context.alb or ahara-infra network outputs"
  type = object({
    arn          = optional(string)
    dns_name     = string
    zone_id      = string
    listener_arn = string
  })
}

variable "cognito" {
  description = "Cognito context, required only when one or more routes have authenticated = true"
  type = object({
    issuer = string
    jwks   = string
  })
  default = null
}
