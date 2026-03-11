variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names (company-environment)."
}

variable "alert_email" {
  type        = string
  description = "Email address for alert notifications."
}

variable "kms_key_id" {
  type        = string
  description = "KMS key ID for encrypting the SNS topic."
  default     = ""
}

variable "cloudtrail_log_group_name" {
  type        = string
  description = "CloudWatch log group name that receives CloudTrail events."
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources."
  default     = {}
}
