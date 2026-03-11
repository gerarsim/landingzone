output "audit_bucket_name" {
  value       = google_storage_bucket.audit_logs.name
  description = "Name of the GCS bucket receiving audit log sink output."
}

output "audit_log_sink_name" {
  value       = google_logging_project_sink.audit.name
  description = "Name of the Cloud Logging sink."
}

output "notification_channel_id" {
  value       = google_monitoring_notification_channel.email.id
  description = "Cloud Monitoring notification channel ID."
}
