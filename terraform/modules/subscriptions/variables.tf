variable "location" { type = string }
variable "tags"     { type = map(string); default = {} }

variable "subscriptions" {
  description = "Map of subscriptions to onboard"
  type = map(object({
    subscription_id     = string
    management_group_id = string
    purpose             = string
    owner               = string
    lock                = bool
  }))
  default = {}
}
