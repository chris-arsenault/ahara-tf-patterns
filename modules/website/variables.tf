variable "prefix" {
  description = "Project resource prefix (must match the deployer IAM scope, e.g. 'tastebase')"
  type        = string
}

variable "hostname" {
  description = "FQDN for the site (e.g. app.ahara.io)"
  type        = string
}

variable "site_directory" {
  description = "Path to the built site files to upload"
  type        = string
}

variable "runtime_config" {
  description = "Key-value map injected as window.__APP_CONFIG__ via config.js"
  type        = map(any)
  default     = {}
}

variable "encrypt" {
  description = "Enable KMS encryption on the S3 bucket"
  type        = bool
  default     = true
}

variable "og_config" {
  description = "OpenGraph route configuration. When set, deploys the platform OG server as a CloudFront origin for dynamic HTML generation."
  type = object({
    site_name = string
    defaults = object({
      title       = string
      description = string
      image       = optional(string, "")
    })
    routes = list(object({
      pattern     = string
      query       = string
      match_field = optional(string)
      title       = string
      description = string
      image       = optional(string)
      og_type     = optional(string, "article")
    }))
    environment = optional(map(string), {})
  })
  default = null
}
