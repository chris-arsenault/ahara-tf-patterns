variable "hostname" {
  description = "FQDN for the site (e.g. app.ahara.io)"
  type        = string
}

variable "site_directory" {
  description = "Path to the built SPA files to upload"
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
