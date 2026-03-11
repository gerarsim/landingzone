output "vpc_id" {
  value       = module.networking.vpc_id
  description = "VPC network ID."
}

output "vpc_name" {
  value       = module.networking.vpc_name
  description = "VPC network name."
}

output "subnet_id" {
  value       = module.networking.subnet_id
  description = "Primary hub subnet ID."
}

output "kms_key_ring_id" {
  value       = module.security.kms_key_ring_id
  description = "KMS key ring ID."
}

output "kms_crypto_key_id" {
  value       = module.security.kms_crypto_key_id
  description = "KMS crypto key ID."
}

output "audit_bucket_name" {
  value       = module.monitoring.audit_bucket_name
  description = "GCS audit log bucket name."
}

output "terraform_sa_email" {
  value       = module.identity.terraform_sa_email
  description = "Terraform automation SA email."
}

output "pubsub_budget_topic" {
  value       = module.budget.pubsub_topic_id
  description = "Pub/Sub topic ID for budget alerts."
}

output "notification_channel_id" {
  value       = module.monitoring.notification_channel_id
  description = "Cloud Monitoring notification channel ID."
}

output "landing_zone_summary" {
  value = {
    company            = var.company_name
    environment        = var.environment
    region             = var.region
    project_id         = var.project_id
    project_number     = data.google_project.current.number
    vpc_name           = module.networking.vpc_name
    kms_key_ring       = module.security.kms_key_ring_id
    audit_bucket       = module.monitoring.audit_bucket_name
    terraform_sa       = module.identity.terraform_sa_email
    monthly_budget     = var.monthly_budget
  }
}
