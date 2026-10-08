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
