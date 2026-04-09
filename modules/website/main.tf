locals {
  prefix = var.prefix

  # All FQDNs this distribution serves (primary + optional aliases)
  all_hostnames = concat([var.hostname], var.aliases)

  # Per-hostname zone resolution. Each hostname's zone defaults to its
  # last two labels (works for both apex and subdomains). The primary
  # hostname additionally honors var.zone_name as an explicit override.
  hostname_to_zone = {
    for h in local.all_hostnames : h => (
      h == var.hostname && var.zone_name != null
      ? var.zone_name
      : join(".", slice(split(".", h), length(split(".", h)) - 2, length(split(".", h))))
    )
  }

  unique_zones = toset(values(local.hostname_to_zone))

  bucket_name = "${local.prefix}-frontend"
  has_og      = var.og_config != null

  # Files to skip in S3 upload
  skip_files = toset(concat(
    ["config.js"],
    local.has_og ? ["index.html"] : []
  ))

  site_files = {
    for file in fileset(var.site_directory, "**") :
    file => file
    if !contains(local.skip_files, file)
  }

  # Known no-cache files (PWA + SPA entry)
  no_cache_files = toset(["index.html", "sw.js", "manifest.webmanifest"])

  mime_types = {
    ".html"        = "text/html"
    ".css"         = "text/css"
    ".js"          = "application/javascript"
    ".json"        = "application/json"
    ".svg"         = "image/svg+xml"
    ".png"         = "image/png"
    ".jpg"         = "image/jpeg"
    ".jpeg"        = "image/jpeg"
    ".gif"         = "image/gif"
    ".ico"         = "image/x-icon"
    ".xml"         = "application/xml"
    ".txt"         = "text/plain"
    ".pdf"         = "application/pdf"
    ".woff"        = "font/woff"
    ".woff2"       = "font/woff2"
    ".ttf"         = "font/ttf"
    ".eot"         = "application/vnd.ms-fontobject"
    ".map"         = "application/json"
    ".webp"        = "image/webp"
    ".avif"        = "image/avif"
    ".wasm"        = "application/wasm"
    ".webmanifest" = "application/manifest+json"
  }

  # Auto-detect Vite entry points from build output
  entry_js  = one([for f in fileset(var.site_directory, "assets/index-*.js") : "/${f}"])
  entry_css = one([for f in fileset(var.site_directory, "assets/*.css") : "/${f}"])

  s3_origin_id     = "S3-${local.prefix}"
  lambda_origin_id = "Lambda-${local.prefix}-og"
}

data "aws_route53_zone" "zones" {
  for_each     = local.unique_zones
  name         = "${each.value}."
  private_zone = false
}

data "aws_caller_identity" "current" {}

# =============================================================================
# S3
# =============================================================================

resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# --- KMS encryption (optional) ---

resource "aws_kms_key" "this" {
  count                   = var.encrypt ? 1 : 0
  description             = "KMS key for ${local.bucket_name} S3 bucket"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudFrontDecrypt"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.this.arn
          }
        }
      }
    ]
  })
}

resource "aws_kms_alias" "this" {
  count         = var.encrypt ? 1 : 0
  name          = "alias/${local.prefix}-bucket"
  target_key_id = aws_kms_key.this[0].key_id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count  = var.encrypt ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.this[0].arn
    }
  }
}

# --- Bucket policy ---

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.this.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.this.arn
          }
        }
      }
    ]
  })
}

# --- File uploads ---

resource "aws_s3_object" "files" {
  for_each = local.site_files

  bucket        = aws_s3_bucket.this.id
  key           = each.key
  source        = "${var.site_directory}/${each.key}"
  source_hash   = filemd5("${var.site_directory}/${each.key}")
  content_type  = local.mime_types[regex("\\.[^.]+$", each.key)]
  cache_control = contains(local.no_cache_files, each.key) ? "no-cache" : "public, max-age=31536000, immutable"
}

resource "aws_s3_object" "config" {
  bucket        = aws_s3_bucket.this.id
  key           = "config.js"
  content_type  = "application/javascript"
  cache_control = "no-cache"

  content = <<-EOT
// Auto-generated by Terraform - Do not edit manually
window.__APP_CONFIG__ = Object.assign(window.__APP_CONFIG__ || {}, ${jsonencode(var.runtime_config)});
EOT
}

# =============================================================================
# OG Lambda (when og_config is set)
# =============================================================================

# Note: when og_config is set, caller MUST also pass vpc and og_artifact.
# These were previously fetched via platform-context + SSM data sources, which
# caused duplicate state entries when a consumer instantiated multiple website
# modules. Consumers now call platform-context once and forward the context.

resource "aws_iam_role" "og" {
  count = local.has_og ? 1 : 0
  name  = "${local.prefix}-og-server"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "og_basic" {
  count      = local.has_og ? 1 : 0
  role       = aws_iam_role.og[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "og_vpc" {
  count      = local.has_og ? 1 : 0
  role       = aws_iam_role.og[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_cloudwatch_log_group" "og" {
  count             = local.has_og ? 1 : 0
  name              = "/aws/lambda/${local.prefix}-og-server"
  retention_in_days = 14
}

resource "aws_lambda_function" "og" {
  count         = local.has_og ? 1 : 0
  function_name = "${local.prefix}-og-server"
  role          = aws_iam_role.og[0].arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  architectures = ["x86_64"]
  timeout       = 10
  memory_size   = 256

  s3_bucket = var.og_artifact.bucket
  s3_key    = var.og_artifact.key

  vpc_config {
    subnet_ids         = var.vpc.private_subnet_ids
    security_group_ids = [var.vpc.lambda_sg_id]
  }

  environment {
    variables = merge(var.og_config.environment, {
      OG_CONFIG = jsonencode({
        site_name = var.og_config.site_name
        defaults  = var.og_config.defaults
        routes    = var.og_config.routes
      })
      ENTRY_JS  = local.entry_js
      ENTRY_CSS = local.entry_css
      SITE_URL  = "https://${var.hostname}"
    })
  }

  depends_on = [aws_cloudwatch_log_group.og]
}

resource "aws_lambda_function_url" "og" {
  count              = local.has_og ? 1 : 0
  function_name      = aws_lambda_function.og[0].function_name
  authorization_type = "NONE"
}

# =============================================================================
# CloudFront
# =============================================================================

resource "aws_wafv2_web_acl" "this" {
  name        = "${local.prefix}-cf-waf"
  description = "WAF for ${var.hostname} CloudFront"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${replace(local.prefix, "-", "")}CfWaf"
    sampled_requests_enabled   = true
  }
}

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${local.prefix}-oac"
  description                       = "OAC for ${var.hostname}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = local.has_og ? null : "index.html"
  aliases             = local.all_hostnames
  price_class         = "PriceClass_100"
  web_acl_id          = aws_wafv2_web_acl.this.arn

  # Origin: S3 for static assets
  origin {
    domain_name              = aws_s3_bucket.this.bucket_regional_domain_name
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  # Origin: OG Lambda for HTML (when enabled)
  dynamic "origin" {
    for_each = local.has_og ? [1] : []
    content {
      domain_name = replace(replace(aws_lambda_function_url.og[0].function_url, "https://", ""), "/", "")
      origin_id   = local.lambda_origin_id

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  # --- OG mode: ordered cache behaviors route static assets to S3 ---

  dynamic "ordered_cache_behavior" {
    for_each = local.has_og ? [1] : []
    content {
      path_pattern           = "/assets/*"
      allowed_methods        = ["GET", "HEAD"]
      cached_methods         = ["GET", "HEAD"]
      target_origin_id       = local.s3_origin_id
      viewer_protocol_policy = "redirect-to-https"
      compress               = true
      min_ttl                = 31536000
      default_ttl            = 31536000
      max_ttl                = 31536000

      forwarded_values {
        query_string = false
        cookies { forward = "none" }
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = local.has_og ? [1] : []
    content {
      path_pattern           = "/config.js"
      allowed_methods        = ["GET", "HEAD"]
      cached_methods         = ["GET", "HEAD"]
      target_origin_id       = local.s3_origin_id
      viewer_protocol_policy = "redirect-to-https"
      compress               = true
      min_ttl                = 0
      default_ttl            = 0
      max_ttl                = 300

      forwarded_values {
        query_string = false
        cookies { forward = "none" }
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = local.has_og ? ["sw.js", "manifest.webmanifest"] : []
    content {
      path_pattern           = "/${ordered_cache_behavior.value}"
      allowed_methods        = ["GET", "HEAD"]
      cached_methods         = ["GET", "HEAD"]
      target_origin_id       = local.s3_origin_id
      viewer_protocol_policy = "redirect-to-https"
      compress               = true
      min_ttl                = 0
      default_ttl            = 0
      max_ttl                = 0

      forwarded_values {
        query_string = false
        cookies { forward = "none" }
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = local.has_og ? [1] : []
    content {
      path_pattern           = "/workbox-*.js"
      allowed_methods        = ["GET", "HEAD"]
      cached_methods         = ["GET", "HEAD"]
      target_origin_id       = local.s3_origin_id
      viewer_protocol_policy = "redirect-to-https"
      compress               = true
      min_ttl                = 31536000
      default_ttl            = 31536000
      max_ttl                = 31536000

      forwarded_values {
        query_string = false
        cookies { forward = "none" }
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = local.has_og ? ["*.png", "*.svg", "*.ico", "*.jpg", "*.webp"] : []
    content {
      path_pattern           = ordered_cache_behavior.value
      allowed_methods        = ["GET", "HEAD"]
      cached_methods         = ["GET", "HEAD"]
      target_origin_id       = local.s3_origin_id
      viewer_protocol_policy = "redirect-to-https"
      compress               = true
      min_ttl                = 3600
      default_ttl            = 86400
      max_ttl                = 604800

      forwarded_values {
        query_string = false
        cookies { forward = "none" }
      }
    }
  }

  # --- Default behavior ---

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.has_og ? local.lambda_origin_id : local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # SPA routing fallback (only when no OG Lambda — Lambda handles all HTML)
  dynamic "custom_error_response" {
    for_each = local.has_og ? [] : [404, 403]
    content {
      error_code         = custom_error_response.value
      response_code      = 200
      response_page_path = "/index.html"
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.this.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# --- Invalidation on deploy ---

resource "terraform_data" "deployment_marker" {
  # Trigger invalidation on changes to: static files, runtime_config (which
  # is interpolated into config.js), or og_config (which is baked into the
  # OG Lambda environment but also affects served HTML).
  input = sha256(jsonencode({
    files          = [for k, v in aws_s3_object.files : v.source_hash]
    runtime_config = var.runtime_config
    og_config      = var.og_config
  }))

  lifecycle {
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aws_cloudfront_create_invalidation.invalidate_all]
    }
  }
}

action "aws_cloudfront_create_invalidation" "invalidate_all" {
  config {
    distribution_id = aws_cloudfront_distribution.this.id
    paths           = ["/*"]
  }
}

# =============================================================================
# ACM + DNS
# =============================================================================

resource "aws_acm_certificate" "this" {
  domain_name               = var.hostname
  subject_alternative_names = var.aliases
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options :
    dvo.domain_name => {
      name    = dvo.resource_record_name
      type    = dvo.resource_record_type
      value   = dvo.resource_record_value
      zone_id = data.aws_route53_zone.zones[local.hostname_to_zone[dvo.domain_name]].zone_id
    }
  }

  allow_overwrite = true
  zone_id         = each.value.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.value]
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

resource "aws_route53_record" "this" {
  zone_id = data.aws_route53_zone.zones[local.hostname_to_zone[var.hostname]].zone_id
  name    = var.hostname
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "ipv6" {
  zone_id = data.aws_route53_zone.zones[local.hostname_to_zone[var.hostname]].zone_id
  name    = var.hostname
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

# Additional aliases — separate resources so existing single-hostname
# consumers have no state moves.
resource "aws_route53_record" "alias_a" {
  for_each = toset(var.aliases)

  zone_id = data.aws_route53_zone.zones[local.hostname_to_zone[each.value]].zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "alias_aaaa" {
  for_each = toset(var.aliases)

  zone_id = data.aws_route53_zone.zones[local.hostname_to_zone[each.value]].zone_id
  name    = each.value
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
