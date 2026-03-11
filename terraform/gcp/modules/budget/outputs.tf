output "pubsub_topic_id" {
  value       = google_pubsub_topic.budget_alerts.id
  description = "Pub/Sub topic ID for budget alerts."
}

output "pubsub_subscription_id" {
  value       = google_pubsub_subscription.budget_alerts.id
  description = "Pub/Sub subscription ID for budget alerts."
}

output "budget_id" {
  value       = var.billing_account_id != "" ? google_billing_budget.main[0].id : ""
  description = "Billing budget ID (empty if billing_account_id not provided)."
}
