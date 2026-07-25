variable "prefix" {
  description = "Project resource prefix (must match the deployer IAM scope, e.g. 'tastebase')"
  type        = string
}

variable "bucket_name" {
  description = "Explicit S3 bucket name for an existing deployment. Defaults to the account-scoped <prefix>-frontend-<account_id> convention."
  type        = string
  default     = null

  validation {
    condition     = var.bucket_name == null ? true : length(trimspace(var.bucket_name)) > 0
    error_message = "bucket_name must be null or a non-empty string."
  }
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

variable "static_asset_path_patterns" {
  description = "Additional CloudFront path patterns to route to the S3 origin when OpenGraph routing is enabled (for example, [\"masks/*\"])."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for pattern in var.static_asset_path_patterns : length(trimspace(pattern)) > 0])
    error_message = "static_asset_path_patterns must contain only non-empty patterns."
  }
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
