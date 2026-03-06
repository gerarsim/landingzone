variable "company_name"         { type = string }
variable "environment"          { type = string }
variable "location"             { type = string }
variable "tags"                 { type = map(string); default = {} }

variable "hub_address_space" {
  type    = string
  default = "10.0.0.0/16"
}

variable "spoke_address_spaces" {
  type    = map(string)
  default = { workloads = "10.1.0.0/16", dmz = "10.2.0.0/16" }
}

variable "enable_firewall"    { type = bool; default = false }
variable "enable_vpn_gateway" { type = bool; default = false }
variable "enable_bastion"     { type = bool; default = true }
