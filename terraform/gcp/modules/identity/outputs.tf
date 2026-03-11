output "terraform_sa_email" {
  value       = google_service_account.terraform.email
  description = "Email of the Terraform automation service account."
}

output "app_sa_email" {
  value       = google_service_account.app.email
  description = "Email of the application workload service account."
}

output "auditor_sa_email" {
  value       = google_service_account.auditor.email
  description = "Email of the auditor (read-only) service account."
}

output "workload_identity_pool_id" {
  value       = google_iam_workload_identity_pool.main.name
  description = "Workload Identity Pool resource name."
}
