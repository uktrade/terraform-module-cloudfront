output "aws_s3_bucket" {
  value = aws_s3_bucket.redirect
}

output "aws_s3_bucket_website_configuration" {
  value = try( aws_s3_bucket_website_configuration.redirect[0], null )
}
