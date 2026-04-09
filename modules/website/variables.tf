variable "prefix" {
  description = "Project resource prefix (must match the deployer IAM scope, e.g. 'tastebase')"
  type        = string
}

variable "hostname" {
  description = "FQDN for the site (e.g. app.ahara.io or ahara.io)"
  type        = string
}

variable "zone_name" {
  description = "Route53 zone name for the primary hostname. Defaults to the last two labels of hostname. Override for delegated subzones or multi-label TLDs."
  type        = string
  default     = null
}

variable "aliases" {
  description = "Additional FQDNs this distribution should also serve. Each is added to the CloudFront alias list, covered by the ACM cert as a SAN, and pointed at the distribution via Route53 A/AAAA records. Zones are auto-derived from each hostname (last 2 labels)."
  type        = list(string)
  default     = []
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

variable "vpc" {
  description = "VPC context, required only when og_config is set (for the OG server Lambda's vpc_config). Typically from platform-context.vpc."
  type = object({
    private_subnet_ids = list(string)
    lambda_sg_id       = string
  })
  default = null
}

variable "og_artifact" {
  description = "OG server Lambda artifact location in S3, required only when og_config is set. Typically { bucket = platform-context.og_server.bucket, key = platform-context.og_server.key } or hardcoded in the consumer."
  type = object({
    bucket = string
    key    = string
  })
  default = null
}
