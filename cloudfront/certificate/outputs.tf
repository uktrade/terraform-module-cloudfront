output "aws_acm_certificate" {
  value = aws_acm_certificate.cert
}

output "aws_route53_record" {
  value = aws_route53_record.validation_record
}
