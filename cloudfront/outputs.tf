output "aws_cloudfront_distribution" {
  value = aws_cloudfront_distribution.standard
}

output "aws_acm_certificate" {
  value = aws_acm_certificate.cert
}
