variable "company_name"        { type = string }
variable "environment"         { type = string }
variable "location"            { type = string }
variable "resource_group_name" { type = string }
variable "alert_email" {
  type    = string
  default = "ops@example.com"
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "log_retention_days" {
  type    = number
  default = 30
}