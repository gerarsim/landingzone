output "vpc_id" {
  value       = module.networking.vpc_id
  description = "VPC ID."
}

output "public_subnet_ids" {
  value       = module.networking.public_subnet_ids
  description = "Public subnet IDs."
}

output "private_subnet_ids" {
  value       = module.networking.private_subnet_ids
  description = "Private subnet IDs."
}

output "kms_key_arn" {
  value       = module.security.kms_key_arn
  description = "KMS CMK ARN."
}

output "audit_bucket_id" {
  value       = module.security.audit_bucket_id
  description = "S3 audit bucket name."
}

output "cloudtrail_arn" {
  value       = module.security.cloudtrail_arn
  description = "CloudTrail trail ARN."
}

output "guardduty_detector_id" {
  value       = module.security.guardduty_detector_id
  description = "GuardDuty detector ID."
}

output "sns_alerts_arn" {
  value       = module.monitoring.sns_topic_arn
  description = "SNS topic ARN for security alerts."
}

output "iam_group_admins" {
  value       = module.identity.group_admins_name
  description = "IAM admin group name."
}

output "break_glass_role_arn" {
  value       = module.identity.break_glass_role_arn
  description = "Break-glass emergency role ARN."
}

output "landing_zone_summary" {
  value = {
    company        = var.company_name
    environment    = var.environment
    region         = var.region
    account_id     = data.aws_caller_identity.current.account_id
    vpc_id         = module.networking.vpc_id
    monthly_budget = var.monthly_budget
    kms_key_arn    = module.security.kms_key_arn
    audit_bucket   = module.security.audit_bucket_id
  }
}
