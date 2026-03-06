variable "company_name"     { type = string }
variable "environment"      { type = string }
variable "subscription_id"  { type = string }
variable "monthly_budget"   { type = number; default = 1000 }
variable "alert_email"      { type = string; default = "ops@example.com" }
