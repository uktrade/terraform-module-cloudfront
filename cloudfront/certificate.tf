module "cloudfront_certificate" {
  providers = {
    aws.default = aws.us-east-1
  }
  count = can( var.args.acm_certificate.domain_name ) ? 1 : 0
  source = "./certificate"

  args = var.args
  tags = local.tags
}
