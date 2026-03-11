variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names (company-environment)."
}

variable "region" {
  type        = string
  description = "GCP region."
}

variable "subnet_cidr" {
  type        = string
  description = "Primary CIDR for the hub subnet."
  default     = "10.0.0.0/24"
}

variable "pods_cidr" {
  type        = string
  description = "Secondary CIDR range for GKE pods."
  default     = "10.1.0.0/16"
}

variable "services_cidr" {
  type        = string
  description = "Secondary CIDR range for GKE services."
  default     = "10.2.0.0/20"
}

variable "enable_cloud_nat" {
  type        = bool
  description = "Deploy Cloud NAT for private outbound internet access."
  default     = true
}
