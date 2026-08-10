variable "name" {
  description = "App client name (e.g. tastebase-app)"
  type        = string
}

variable "callback_urls" {
  description = "OAuth callback URLs. If non-empty, creates a confidential client with authorization code grant."
  type        = list(string)
  default     = []
}

variable "logout_urls" {
  description = "OAuth logout URLs. Only used when callback_urls is non-empty."
  type        = list(string)
  default     = []
}

variable "public_oauth_client" {
  description = "Create an OAuth code-flow client without a secret for a browser PKCE flow. Requires callback_urls."
  type        = bool
  default     = false

  validation {
    condition     = var.public_oauth_client ? length(var.callback_urls) > 0 : true
    error_message = "public_oauth_client requires at least one callback URL."
  }
}

variable "cognito" {
  description = "Cognito context, typically from platform-context.cognito output."
  type = object({
    user_pool_id = string
  })
}
