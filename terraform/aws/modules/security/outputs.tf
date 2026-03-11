output "kms_key_arn" {
  value       = aws_kms_key.main.arn
  description = "ARN of the KMS Customer Managed Key."
}

output "kms_key_id" {
  value       = aws_kms_key.main.key_id
  description = "ID of the KMS Customer Managed Key."
}

output "audit_bucket_id" {
  value       = aws_s3_bucket.audit.id
  description = "Name of the S3 audit bucket (CloudTrail logs)."
}

output "audit_bucket_arn" {
  value       = aws_s3_bucket.audit.arn
  description = "ARN of the S3 audit bucket."
}

output "cloudtrail_arn" {
  value       = aws_cloudtrail.main.arn
  description = "ARN of the CloudTrail trail."
}

output "guardduty_detector_id" {
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].id : ""
  description = "GuardDuty detector ID."
}
