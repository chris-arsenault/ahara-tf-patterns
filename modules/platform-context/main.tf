# Platform Context — reads shared platform resources via tag-based
# lookups and name-based lookups where possible, SSM for the rest.

# =============================================================================
# Network — tag-based and derived lookups
# =============================================================================

data "aws_vpc" "this" {
  filter {
    name   = "tag:vpc:role"
    values = ["ahara"]
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
    "lb:role" = "ahara"
  }
}

data "aws_lb_listener" "https" {
  load_balancer_arn = data.aws_lb.this.arn
  port              = 443
}

data "aws_security_group" "ahara_lambda" {
  filter {
    name   = "tag:sg:role"
    values = ["lambda"]
  }
  filter {
    name   = "tag:sg:scope"
    values = ["ahara"]
  }
}

data "aws_security_group" "vpn_client" {
  filter {
    name   = "tag:sg:role"
    values = ["vpn-client"]
  }
  filter {
    name   = "tag:sg:scope"
    values = ["ahara"]
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
  name = "/ahara/cognito/user-pool-id"
}

data "aws_ssm_parameter" "cognito_user_pool_arn" {
  name = "/ahara/cognito/user-pool-arn"
}

data "aws_ssm_parameter" "cognito_domain" {
  name = "/ahara/cognito/domain"
}

data "aws_ssm_parameter" "cognito_issuer_url" {
  name = "/ahara/cognito/issuer-url"
}

# =============================================================================
# RDS — SSM for connection details, tags for security group
# =============================================================================

data "aws_ssm_parameter" "rds_endpoint" {
  name = "/ahara/rds/endpoint"
}

data "aws_ssm_parameter" "rds_address" {
  name = "/ahara/rds/address"
}

data "aws_ssm_parameter" "rds_port" {
  name = "/ahara/rds/port"
}

data "aws_security_group" "rds" {
  filter {
    name   = "tag:sg:role"
    values = ["rds"]
  }
  filter {
    name   = "tag:sg:scope"
    values = ["ahara"]
  }
}
