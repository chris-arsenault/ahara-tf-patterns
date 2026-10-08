mock_provider "aws" {
  override_during = plan
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "559098897826"
      arn        = "arn:aws:iam::559098897826:role/synthetic-test"
      user_id    = "synthetic-test"
    }
  }
  mock_data "aws_route53_zone" {
    defaults = { zone_id = "ZSYNTHETIC", name = "ahara.io." }
  }
}

override_resource {
  target          = aws_acm_certificate.this
  override_during = plan
  values = {
    arn = "arn:aws:acm:us-east-1:559098897826:certificate/00000000-0000-0000-0000-000000000000"
    domain_validation_options = [{
      domain_name           = "pdf.ahara.io"
      resource_record_name  = "_synthetic.pdf.ahara.io"
      resource_record_type  = "CNAME"
      resource_record_value = "synthetic.acm-validations.aws."
    }]
  }
}

variables {
  prefix         = "pdfree"
  hostname       = "pdf.ahara.io"
  site_directory = "./tests/assets"
  encrypt        = false
}

run "pdf_assets" {
  command = plan
  assert {
    condition = (
      local.entry_js == null && local.entry_css == null &&
      length(aws_lambda_function.og) == 0 &&
      aws_cloudfront_distribution.this.default_root_object == "index.html"
    )
    error_message = "Static sites must use their built HTML without evaluating dynamic OG entry discovery."
  }
  assert {
    condition = (
      aws_s3_object.files["assets/index-app.js"].content_type == "application/javascript" &&
      aws_s3_object.files["assets/index-worker.js"].content_type == "application/javascript" &&
      aws_s3_object.files["assets/index-app.css"].content_type == "text/css" &&
      aws_s3_object.files["assets/index-worker.css"].content_type == "text/css"
    )
    error_message = "Static sites must retain all scripts and styles even when multiple filenames match the OG entry patterns."
  }
  assert {
    condition     = aws_s3_bucket.this.bucket == "pdfree-frontend-559098897826"
    error_message = "The website bucket must remain account-scoped."
  }
  assert {
    condition = (
      aws_s3_object.files["worker.mjs"].content_type == "application/javascript" &&
      aws_s3_object.files["map.bcmap"].content_type == "application/octet-stream" &&
      aws_s3_object.files["font.pfb"].content_type == "application/octet-stream" &&
      aws_s3_object.files["profile.icc"].content_type == "application/vnd.iccprofile"
    )
    error_message = "PDF.js workers and binary resources must receive usable MIME types."
  }
  assert {
    condition = (
      aws_s3_object.files["sw.js"].cache_control == "no-cache" &&
      aws_s3_object.files["worker.mjs"].cache_control == "public, max-age=31536000, immutable"
    )
    error_message = "Service-worker updates must revalidate while versioned PDF assets remain immutable."
  }
}

run "dynamic_og_entry" {
  command = plan
  variables {
    site_directory = "./tests/og-assets"
    vpc = {
      private_subnet_ids = ["subnet-synthetic"]
      lambda_sg_id       = "sg-synthetic"
    }
    og_artifact = {
      bucket = "synthetic-platform-artifacts"
      key    = "og-server.zip"
    }
    og_config = {
      site_name = "Existing OpenGraph site"
      defaults = {
        title       = "Existing entry contract"
        description = "Keep the dynamic renderer's entry paths unchanged."
      }
    }
  }
  assert {
    condition = (
      aws_lambda_function.og[0].environment[0].variables["ENTRY_JS"] == "/assets/index-app.js" &&
      aws_lambda_function.og[0].environment[0].variables["ENTRY_CSS"] == "/assets/index-app.css"
    )
    error_message = "Dynamic OpenGraph sites must keep their existing entry discovery contract."
  }
  assert {
    condition = (
      !contains(keys(aws_s3_object.files), "index.html") &&
      contains(keys(aws_s3_object.files), "assets/chunk-index-dependency.js") &&
      aws_cloudfront_distribution.this.default_root_object == null
    )
    error_message = "Dynamic sites must keep serving HTML through the OG origin and uploading dependency chunks to S3."
  }
}
