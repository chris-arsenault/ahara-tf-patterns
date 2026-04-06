# Platform Context — reads shared platform resources via tag-based
# lookups and name-based lookups where possible, SSM for the rest.

# =============================================================================
# Network — tag-based and derived lookups
# =============================================================================

data "aws_vpc" "this" {
  filter {
    name   = "tag:vpc:role"
    values = ["platform"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "tag:subnet:access"
    values = ["private"]
  }
}

data "aws_lb" "this" {
  tags = {
    "lb:role" = "platform"
  }
}

data "aws_lb_listener" "https" {
  load_balancer_arn = data.aws_lb.this.arn
  port              = 443
}

data "aws_security_group" "platform_lambda" {
  filter {
    name   = "tag:sg:role"
    values = ["lambda"]
  }
  filter {
    name   = "tag:sg:scope"
    values = ["platform"]
  }
}

data "aws_security_group" "vpn_client" {
  filter {
    name   = "tag:sg:role"
    values = ["vpn-client"]
  }
  filter {
    name   = "tag:sg:scope"
    values = ["platform"]
  }
}

data "aws_route53_zone" "this" {
  name         = "ahara.io."
  private_zone = false
}

# =============================================================================
# Cognito — SSM (no tag-based data source for Cognito pools)
# =============================================================================

data "aws_ssm_parameter" "cognito_user_pool_id" {
  name = "/platform/cognito/user-pool-id"
}

data "aws_ssm_parameter" "cognito_user_pool_arn" {
  name = "/platform/cognito/user-pool-arn"
}

data "aws_ssm_parameter" "cognito_domain" {
  name = "/platform/cognito/domain"
}

data "aws_ssm_parameter" "cognito_issuer_url" {
  name = "/platform/cognito/issuer-url"
}

# =============================================================================
# RDS — SSM for connection details, tags for security group
# =============================================================================

data "aws_ssm_parameter" "rds_endpoint" {
  name = "/platform/rds/endpoint"
}

data "aws_ssm_parameter" "rds_address" {
  name = "/platform/rds/address"
}

data "aws_ssm_parameter" "rds_port" {
  name = "/platform/rds/port"
}

data "aws_security_group" "rds" {
  filter {
    name   = "tag:sg:role"
    values = ["rds"]
  }
  filter {
    name   = "tag:sg:scope"
    values = ["platform"]
  }
}
