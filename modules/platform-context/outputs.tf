# Network

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

output "route53_zone_id" {
  value = data.aws_route53_zone.this.zone_id
}

# Cognito

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

# RDS

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
