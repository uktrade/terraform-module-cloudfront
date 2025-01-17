terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [ aws.default ]
    }
  }
}

locals {
  tags = merge(
    { "Terraform_source_repo" = "terraform-module-cloudfront" },
    var.tags
  )
}


resource "aws_s3_bucket" "redirect" {
  provider = aws.default
  bucket = var.args.bucket
  tags = local.tags
}

resource "aws_s3_bucket_website_configuration" "redirect" {
  provider = aws.default
  count = can( try(var.args.redirect_all_requests_to, var.args.routing_rule, var.args.routing_rules, var.args.cloudfront_origin) ) ? 1 : 0
  bucket = aws_s3_bucket.redirect.id

  dynamic "redirect_all_requests_to" {
    for_each = try( var.args.redirect_all_requests_to, [] )
    content {
      host_name = redirect_all_requests_to.value.host_name
      protocol  = try( redirect_all_requests_to.value.protocol, "https" )
    }
  }

  dynamic "index_document" {
    for_each = try( var.args.index_document, [] )
    content {
      suffix = index_document.value.suffix
    }
  }

  dynamic "error_document" {
    for_each = try( var.args.error_document, [] )
    content {
      key = error_document.value.key
    }
  }

  dynamic "routing_rule" {
    for_each = try( var.args.routing_rule, [] )
    content {
      dynamic condition {
        for_each = try( routing_rule.value.condition, [] )
        content {
          http_error_code_returned_equals = try( condition.value.http_error_code_returned_equals, null )
          key_prefix_equals = try( condition.value.key_prefix_equals, null )
        }
      }
      dynamic redirect {
        for_each = try( routing_rule.value.redirect, [] )
        content {
          host_name = redirect.value.host_name
          http_redirect_code = try( redirect.value.http_redirect_code, 301)
          protocol = try( redirect.value.protocol, "https" )
          replace_key_prefix_with = try( redirect.value.replace_key_prefix_with, null )
          replace_key_with = try( redirect.value.replace_key_with, null)
        }
      }
    }
  }

  routing_rules = try( var.args.routing_rules, null )

}

resource "aws_s3_bucket_public_access_block" "redirect" {
  provider = aws.default
  bucket = aws_s3_bucket.redirect.id
  block_public_acls = try(
    var.args.aws_s3_bucket_public_access_block.all,
    var.args.aws_s3_bucket_public_access_block.block_public_acls,
    true
  )
  block_public_policy = try(
    var.args.aws_s3_bucket_public_access_block.all,
    var.args.aws_s3_bucket_public_access_block.block_public_policy,
    true
  )
  ignore_public_acls = try(
    var.args.aws_s3_bucket_public_access_block.all,
    var.args.aws_s3_bucket_public_access_block.ignore_public_acls,
    true
  )
  restrict_public_buckets = try(
    var.args.aws_s3_bucket_public_access_block.all,
    var.args.aws_s3_bucket_public_access_block.restrict_public_buckets,
    true
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "redirect_apply_sse" {
  provider = aws.default
  bucket = aws_s3_bucket.redirect.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "redirect_deny_non_https_access" {
  provider = aws.default
  count = can(try(var.args.cloudfront_origin)) ? 0 : 1
  bucket = aws_s3_bucket.redirect.id
  policy = data.aws_iam_policy_document.redirect_deny_non_https_access.json
}

data "aws_iam_policy_document" "redirect_deny_non_https_access" {
  depends_on = [ aws_s3_bucket_public_access_block.redirect ]
   statement {
    sid = "Deny non-HTTPS access"
    actions = ["s3:*"]
    effect = "Deny"
    resources = ["${aws_s3_bucket.redirect.arn}/*"]
    principals {
      type = "*"
      identifiers = ["*"]
    }
    condition {
      test = "Bool"
      variable = "aws:SecureTransport"
      values = ["false"]
    }
  }
}

# When CloudFront is configured to use an S3 bucket as its origin, it defaults to HTTP and can't be changed.
# Instead, we'll want a policy to allow read only access. 
resource "aws_s3_bucket_policy" "redirect_allow_cloudfront_origin" {
  provider = aws.default
  count = can(try(var.args.cloudfront_origin)) ? 1 : 0
  bucket = aws_s3_bucket.redirect.id
  policy = data.aws_iam_policy_document.redirect_allow_cloudfront_origin.json
}

data "aws_iam_policy_document" "redirect_allow_cloudfront_origin" {
  depends_on = [ aws_s3_bucket_public_access_block.redirect ]
   statement {
    sid = "Allow CloudFront Origin Read Access"
    actions = ["s3:GetObject"]
    effect = "Allow"
    resources = ["${aws_s3_bucket.redirect.arn}/*"]
    principals {
      type = "*"
      identifiers = ["*"]
    }
  }
}
