output "aws_cloudfront_distribution" {
  value = aws_cloudfront_distribution.standard
}

output "aws_acm_certificate" {
  value = try( module.cloudfront_certificate.aws_acm_certificate.cert, null )
}
