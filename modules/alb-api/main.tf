locals {
  # Derive a resource prefix from the hostname (e.g. "api-tastebase-ahara-io")
  prefix = replace(var.hostname, ".", "-")

  # Flatten routes so we can for_each over them
  routes = merge([
    for fn_key, fn in var.lambdas : {
      for i, route in fn.routes :
      "${fn_key}-${i}" => merge(route, { fn_key = fn_key })
    }
  ]...)
}

# --- Platform context ---

module "ctx" {
  source = "../platform-context"
}

# --- IAM role (shared across all Lambdas in this module) ---

data "aws_iam_policy_document" "assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.prefix}-lambda"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "inline" {
  count  = var.iam_policy != null ? 1 : 0
  name   = "${local.prefix}-lambda"
  role   = aws_iam_role.lambda.id
  policy = var.iam_policy
}

# --- Security group ---

resource "aws_security_group" "lambda" {
  name_prefix = "${local.prefix}-lambda-"
  description = "Lambda functions for ${var.hostname}"
  vpc_id      = module.ctx.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Lambda functions ---

module "lambda" {
  source   = "../lambda"
  for_each = var.lambdas

  name               = "${local.prefix}-${each.key}"
  zip                = each.value.zip
  role_arn           = aws_iam_role.lambda.arn
  subnet_ids         = module.ctx.private_subnet_ids
  security_group_ids = [aws_security_group.lambda.id]
  environment        = merge(var.environment, each.value.environment)
}

# --- ALB target groups ---

resource "aws_lb_target_group" "this" {
  for_each    = var.lambdas
  name        = "${local.prefix}-${each.key}-tg"
  target_type = "lambda"
}

resource "aws_lambda_permission" "alb" {
  for_each      = var.lambdas
  statement_id  = "AllowALBInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda[each.key].function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.this[each.key].arn
}

resource "aws_lb_target_group_attachment" "this" {
  for_each         = var.lambdas
  target_group_arn = aws_lb_target_group.this[each.key].arn
  target_id        = module.lambda[each.key].function_arn
  depends_on       = [aws_lambda_permission.alb]
}

# --- ALB listener rules ---

resource "aws_lb_listener_rule" "this" {
  for_each     = local.routes
  listener_arn = module.ctx.alb_listener_arn
  priority     = each.value.priority

  condition {
    host_header {
      values = [var.hostname]
    }
  }

  condition {
    path_pattern {
      values = each.value.paths
    }
  }

  dynamic "condition" {
    for_each = each.value.methods != null ? [1] : []
    content {
      http_request_method {
        values = each.value.methods
      }
    }
  }

  dynamic "action" {
    for_each = each.value.authenticated ? [1] : []
    content {
      type = "jwt-validation"

      jwt_validation {
        issuer        = module.ctx.cognito_issuer
        jwks_endpoint = module.ctx.cognito_jwks
      }
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.value.fn_key].arn
  }
}

# --- TLS certificate ---

resource "aws_acm_certificate" "this" {
  domain_name       = var.hostname
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id         = module.ctx.route53_zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.value]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

resource "aws_lb_listener_certificate" "this" {
  listener_arn    = module.ctx.alb_listener_arn
  certificate_arn = aws_acm_certificate_validation.this.certificate_arn
}

# --- DNS ---

resource "aws_route53_record" "this" {
  zone_id = module.ctx.route53_zone_id
  name    = var.hostname
  type    = "A"

  alias {
    name                   = module.ctx.alb_dns_name
    zone_id                = module.ctx.alb_zone_id
    evaluate_target_health = true
  }
}
