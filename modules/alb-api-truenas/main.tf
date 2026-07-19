locals {
  hostname_labels = split(".", var.hostname)
  zone_name = coalesce(
    var.zone_name,
    join(".", slice(local.hostname_labels, length(local.hostname_labels) - 2, length(local.hostname_labels)))
  )

  authenticated_routes = [for r in var.routes : r if try(r.authenticated, true)]
}

data "aws_route53_zone" "this" {
  name         = "${local.zone_name}."
  private_zone = false
}

resource "aws_lb_listener_rule" "this" {
  for_each     = { for i, route in var.routes : tostring(i) => route }
  listener_arn = var.alb.listener_arn
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
    for_each = try(each.value.authenticated, true) ? [1] : []
    content {
      type = "jwt-validation"

      jwt_validation {
        issuer        = var.cognito.issuer
        jwks_endpoint = var.cognito.jwks
      }
    }
  }

  action {
    type             = "forward"
    target_group_arn = var.target_group_arn
  }

  lifecycle {
    precondition {
      condition     = length(local.authenticated_routes) == 0 || var.cognito != null
      error_message = "cognito is required when any route has authenticated = true"
    }
  }
}

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

  zone_id         = data.aws_route53_zone.this.zone_id
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
  listener_arn    = var.alb.listener_arn
  certificate_arn = aws_acm_certificate_validation.this.certificate_arn
}

resource "aws_route53_record" "this" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.hostname
  type    = "A"

  alias {
    name                   = var.alb.dns_name
    zone_id                = var.alb.zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "ipv6" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.hostname
  type    = "AAAA"

  alias {
    name                   = var.alb.dns_name
    zone_id                = var.alb.zone_id
    evaluate_target_health = false
  }
}
