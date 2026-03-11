output "kms_key_ring_id" {
  value       = google_kms_key_ring.main.id
  description = "KMS key ring ID."
}

output "kms_crypto_key_id" {
  value       = google_kms_crypto_key.main.id
  description = "KMS crypto key ID."
}

output "waf_policy_id" {
  value       = var.enable_cloud_armor ? google_compute_security_policy.waf[0].id : ""
  description = "Cloud Armor security policy ID."
}

output "lz_metadata_secret_id" {
  value       = google_secret_manager_secret.lz_metadata.id
  description = "Secret Manager secret ID for LZ metadata."
}
