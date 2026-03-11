variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names (company-environment)."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
  default     = "10.0.0.0/16"
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention in days."
  default     = 90
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources."
  default     = {}
}
