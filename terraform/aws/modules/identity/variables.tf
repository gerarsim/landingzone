variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names (company-environment)."
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources."
  default     = {}
}
