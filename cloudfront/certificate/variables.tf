variable "args" {
  default     = null
  description = "A map of CloudFront arguments to apply to the distribution. Takes precedence over 'defaults' variable values."
  type        = any
}

variable "tags" {
  default     = {}
  description = "A map of tags to assign to the CloudFront distribution."
  type        = map(any)
}
