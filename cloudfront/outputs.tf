output "aws_cloudfront_distribution" {
  value = aws_cloudfront_distribution.standard
}

output "aws_acm_certificate" {
  value = try( aws_acm_certificate.cert[0], null )
}
