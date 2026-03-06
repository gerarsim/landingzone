variable "management_group_id" {
  type        = string
  description = "Management Group ID to assign policies to"
}

variable "environment" {
  type = string
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "allowed_locations" {
  type        = list(string)
  description = "List of allowed Azure regions"
  default     = ["westeurope", "northeurope", "uksouth", "ukwest"]
}
