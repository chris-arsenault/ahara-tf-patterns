# =============================================================================
# Grouped context outputs — pass these to consumer modules (lambda, alb-api,
# cognito-app, website) so they never call platform-context themselves.
#
# This eliminates duplicate data-source reads when a consumer calls multiple
# modules (e.g., alb-api + several lambdas): platform-context is instantiated
# ONCE per consumer, and its grouped outputs are forwarded as inputs.
# =============================================================================

output "vpc" {
  description = "VPC context: pass to lambda.vpc, alb-api.vpc, website.vpc"
  value = {
    vpc_id             = data.aws_vpc.this.id
    private_subnet_ids = data.aws_subnets.private.ids
    lambda_sg_id       = data.aws_security_group.ahara_lambda.id
    vpn_client_sg_id   = data.aws_security_group.vpn_client.id
  }
}

output "alb" {
  description = "ALB context: pass to alb-api.alb"
  value = {
    arn          = data.aws_lb.this.arn
    dns_name     = data.aws_lb.this.dns_name
    zone_id      = data.aws_lb.this.zone_id
    listener_arn = data.aws_lb_listener.https.arn
  }
}

output "cognito" {
  description = "Cognito context: pass to cognito-app.cognito, alb-api.cognito (when using jwt-validation)"
  value = {
    user_pool_id  = nonsensitive(data.aws_ssm_parameter.cognito_user_pool_id.value)
    user_pool_arn = nonsensitive(data.aws_ssm_parameter.cognito_user_pool_arn.value)
    domain        = nonsensitive(data.aws_ssm_parameter.cognito_domain.value)
    issuer        = nonsensitive(data.aws_ssm_parameter.cognito_issuer_url.value)
    jwks          = "${nonsensitive(data.aws_ssm_parameter.cognito_issuer_url.value)}/.well-known/jwks.json"
  }
}

output "rds" {
  description = "RDS context: for consumers that connect directly to the shared DB"
  value = {
    endpoint          = nonsensitive(data.aws_ssm_parameter.rds_endpoint.value)
    address           = nonsensitive(data.aws_ssm_parameter.rds_address.value)
    port              = nonsensitive(data.aws_ssm_parameter.rds_port.value)
    security_group_id = data.aws_security_group.rds.id
  }
}

output "og_server" {
  description = "OG server Lambda artifact S3 location: pass to website.og_artifact when using og_config"
  value = {
    bucket = nonsensitive(data.aws_ssm_parameter.og_server_s3_bucket.value)
    key    = nonsensitive(data.aws_ssm_parameter.og_server_s3_key.value)
  }
}

output "route53_zone_id" {
  description = "Route53 zone id for ahara.io"
  value       = data.aws_route53_zone.this.zone_id
}

# =============================================================================
# Flat outputs (legacy) — retained for backward compatibility with consumer
# code that references fields directly. New callers should use the grouped
# outputs above.
# =============================================================================

output "vpc_id" {
  value = data.aws_vpc.this.id
}

output "private_subnet_ids" {
  value = data.aws_subnets.private.ids
}

output "alb_arn" {
  value = data.aws_lb.this.arn
}

output "alb_dns_name" {
  value = data.aws_lb.this.dns_name
}

output "alb_zone_id" {
  value = data.aws_lb.this.zone_id
}

output "alb_listener_arn" {
  value = data.aws_lb_listener.https.arn
}

output "ahara_lambda_sg_id" {
  value = data.aws_security_group.ahara_lambda.id
}

output "vpn_client_sg_id" {
  value = data.aws_security_group.vpn_client.id
}

output "cognito_user_pool_id" {
  value = nonsensitive(data.aws_ssm_parameter.cognito_user_pool_id.value)
}

output "cognito_user_pool_arn" {
  value = nonsensitive(data.aws_ssm_parameter.cognito_user_pool_arn.value)
}

output "cognito_domain" {
  value = nonsensitive(data.aws_ssm_parameter.cognito_domain.value)
}

output "cognito_issuer" {
  value = nonsensitive(data.aws_ssm_parameter.cognito_issuer_url.value)
}

output "cognito_jwks" {
  value = "${nonsensitive(data.aws_ssm_parameter.cognito_issuer_url.value)}/.well-known/jwks.json"
}

output "rds_endpoint" {
  value = nonsensitive(data.aws_ssm_parameter.rds_endpoint.value)
}

output "rds_address" {
  value = nonsensitive(data.aws_ssm_parameter.rds_address.value)
}

output "rds_port" {
  value = nonsensitive(data.aws_ssm_parameter.rds_port.value)
}

output "rds_security_group_id" {
  value = data.aws_security_group.rds.id
}
