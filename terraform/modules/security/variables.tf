variable "company_name"             { type = string }
variable "environment"              { type = string }
variable "location"                 { type = string }
variable "resource_group_name"      { type = string }
variable "tenant_id"                { type = string }
variable "object_id"                { type = string }
variable "log_analytics_id"         { type = string }
variable "tags"                     { type = map(string); default = {} }

variable "defender_tier" {
  type    = string
  default = "Standard"  # "Free" for demo, "Standard" for prod
}

variable "security_contact_email" {
  type    = string
  default = "security@example.com"
}

variable "key_vault_allowed_ips" {
  type    = list(string)
  default = []
}

variable "key_vault_allowed_subnet_ids" {
  type    = list(string)
  default = []
}
