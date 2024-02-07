variable "args" {
  default     = null
  description = "A map of arguments to apply to the bucket."
  type        = any
}

variable "tags" {
  default     = {}
  description = "A map of tags to assign to the bucket."
  type        = map(any)
}
