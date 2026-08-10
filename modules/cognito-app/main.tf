locals {
  uses_oauth = length(var.callback_urls) > 0
}

# Direct-auth clients have no secret. OAuth clients are confidential unless
# the caller selects the public PKCE mode.
resource "aws_cognito_user_pool_client" "this" {
  name         = var.name
  user_pool_id = var.cognito.user_pool_id

  generate_secret = local.uses_oauth && !var.public_oauth_client

  explicit_auth_flows = var.public_oauth_client ? [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
    ] : [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
  ]

  # OAuth settings for hosted authorization-code clients
  allowed_oauth_flows                  = local.uses_oauth ? ["code"] : null
  allowed_oauth_flows_user_pool_client = local.uses_oauth
  allowed_oauth_scopes                 = local.uses_oauth ? ["openid", "profile", "email"] : null
  callback_urls                        = local.uses_oauth ? var.callback_urls : null
  default_redirect_uri                 = local.uses_oauth ? var.callback_urls[0] : null
  logout_urls                          = local.uses_oauth && length(var.logout_urls) > 0 ? var.logout_urls : null
  supported_identity_providers         = local.uses_oauth ? ["COGNITO"] : null
}
