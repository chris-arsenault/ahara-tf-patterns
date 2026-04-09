locals {
  is_server = length(var.callback_urls) > 0
}

# SPA client: no secret, direct auth flows
# Server client: with secret, OAuth authorization code grant
resource "aws_cognito_user_pool_client" "this" {
  name         = var.name
  user_pool_id = var.cognito.user_pool_id

  generate_secret = local.is_server

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
  ]

  # OAuth settings for server clients
  allowed_oauth_flows                  = local.is_server ? ["code"] : null
  allowed_oauth_flows_user_pool_client = local.is_server
  allowed_oauth_scopes                 = local.is_server ? ["openid", "profile", "email"] : null
  callback_urls                        = local.is_server ? var.callback_urls : null
  logout_urls                          = local.is_server && length(var.logout_urls) > 0 ? var.logout_urls : null
  supported_identity_providers         = local.is_server ? ["COGNITO"] : null
}
