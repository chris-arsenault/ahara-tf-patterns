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

variable "cognito" {
  description = "Cognito context, typically from platform-context.cognito output."
  type = object({
    user_pool_id = string
  })
}
