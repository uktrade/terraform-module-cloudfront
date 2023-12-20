resource "aws_acm_certificate" "cert" {
  provider = aws.us-east-1

  count = can( var.args.acm_certificate.domain_name ) ? 1 : 0
  domain_name = var.args.acm_certificate.domain_name
  subject_alternative_names = try( var.args.acm_certificate.subject_alternative_name, [] )
  validation_method = try( var.args.acm_certificate.validation_method, "DNS" )
  key_algorithm = try( var.args.acm_certificate.key_algorithm, "RSA_2048" )
  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "validation_domain" {
  provider = aws.us-east-1

  count = can( var.args.acm_certificate.dns_validation_route53_zone ) ? 1 : 0
  name = var.args.acm_certificate.dns_validation_route53_zone
  private_zone = try( var.args.acm_certificate.private_zone, null )
  vpc_id = try( var.args.acm_certificate.vpc_id, null )
}

resource "aws_route53_record" "validation_record" {
  provider = aws.us-east-1

  count = can( var.args.acm_certificate.dns_validation_route53_zone ) ? 1 : 0
  zone_id = data.aws_route53_zone.validation_domain[0].zone_id
  name = tolist(aws_acm_certificate.cert[0].domain_validation_options)[0].resource_record_name
  type = tolist(aws_acm_certificate.cert[0].domain_validation_options)[0].resource_record_type
  records = [tolist(aws_acm_certificate.cert[0].domain_validation_options)[0].resource_record_value]
  ttl = try( var.args.acm_certificate.dns_validation_record_ttl, 300 )
}
