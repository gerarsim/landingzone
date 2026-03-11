output "group_admins_name" {
  value       = aws_iam_group.admins.name
  description = "IAM group name for administrators."
}

output "group_developers_name" {
  value       = aws_iam_group.developers.name
  description = "IAM group name for developers."
}

output "group_auditors_name" {
  value       = aws_iam_group.auditors.name
  description = "IAM group name for auditors."
}

output "group_readonly_name" {
  value       = aws_iam_group.readonly.name
  description = "IAM group name for read-only users."
}

output "break_glass_role_arn" {
  value       = aws_iam_role.break_glass.arn
  description = "ARN of the break-glass emergency role."
}

output "readonly_xaccount_role_arn" {
  value       = aws_iam_role.readonly_cross_account.arn
  description = "ARN of the read-only cross-account role."
}
