terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [ aws.default ]
    }
  }
}

resource "aws_acm_certificate" "cert" {
  provider = aws.default

  domain_name = var.args.acm_certificate.domain_name
  subject_alternative_names = try( var.args.acm_certificate.subject_alternative_names, [] )
  validation_method = try( var.args.acm_certificate.validation_method, "DNS" )
  key_algorithm = try( var.args.acm_certificate.key_algorithm, "RSA_2048" )
  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "validation_domain" {
  provider = aws.default

  name = var.args.acm_certificate.dns_validation_route53_zone
  private_zone = try( var.args.acm_certificate.private_zone, null )
  vpc_id = try( var.args.acm_certificate.vpc_id, null )
}

resource "aws_route53_record" "validation_record" {
  provider = aws.default

  for_each = {
    for domain_validation_option in aws_acm_certificate.cert.domain_validation_options : domain_validation_option.domain_name => {
      name = domain_validation_option.resource_record_name
      type = domain_validation_option.resource_record_type
      record = domain_validation_option.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.validation_domain.zone_id
  name = each.value.name
  type = each.value.type
  records = [each.value.record]
  ttl = try( var.args.acm_certificate.dns_validation_record_ttl, 300 )
  allow_overwrite = true
}
