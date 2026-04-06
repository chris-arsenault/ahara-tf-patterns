variable "hostname" {
  description = "FQDN for the site (e.g. docs.ahara.io)"
  type        = string
}

variable "site_directory" {
  description = "Path to the static site files to upload"
  type        = string
}

variable "runtime_config" {
  description = "Key-value map injected as config.js"
  type        = map(any)
  default     = {}
}
