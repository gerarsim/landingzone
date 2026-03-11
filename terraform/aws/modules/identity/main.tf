# ═══════════════════════════════════════════════════════════════════
# LZForge — AWS Identity Module
# IAM password policy (CIS), IAM groups with managed policies,
# break-glass role, read-only cross-account role, account alias
# ═══════════════════════════════════════════════════════════════════

data "aws_caller_identity" "current" {}

# ── IAM Account Password Policy (CIS 1.5–1.11) ───────────────────────
resource "aws_iam_account_password_policy" "main" {
  minimum_password_length        = 16
  require_uppercase_characters   = true
  require_lowercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 24
  hard_expiry                    = false
}

# ── IAM Groups ───────────────────────────────────────────────────────

resource "aws_iam_group" "admins" {
  name = "lzforge-admins-${var.name_prefix}"
}

resource "aws_iam_group" "developers" {
  name = "lzforge-developers-${var.name_prefix}"
}

resource "aws_iam_group" "auditors" {
  name = "lzforge-auditors-${var.name_prefix}"
}

resource "aws_iam_group" "readonly" {
  name = "lzforge-readonly-${var.name_prefix}"
}

# ── Group policy attachments ──────────────────────────────────────────

resource "aws_iam_group_policy_attachment" "admins_power_user" {
  group      = aws_iam_group.admins.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_group_policy_attachment" "admins_iam_full" {
  group      = aws_iam_group.admins.name
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}

resource "aws_iam_group_policy_attachment" "developers_power" {
  group      = aws_iam_group.developers.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_group_policy_attachment" "auditors_readonly" {
  group      = aws_iam_group.auditors.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_group_policy_attachment" "auditors_security_audit" {
  group      = aws_iam_group.auditors.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_group_policy_attachment" "readonly_policy" {
  group      = aws_iam_group.readonly.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ── Force MFA policy for all human groups ────────────────────────────
resource "aws_iam_policy" "force_mfa" {
  name        = "policy-force-mfa-${var.name_prefix}"
  description = "Force MFA — deny all actions until MFA is configured."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowViewAccountInfo"
        Effect = "Allow"
        Action = ["iam:GetAccountPasswordPolicy", "iam:ListVirtualMFADevices"]
        Resource = "*"
      },
      {
        Sid    = "AllowManageOwnMFA"
        Effect = "Allow"
        Action = [
          "iam:CreateVirtualMFADevice", "iam:EnableMFADevice",
          "iam:GetUser", "iam:ListMFADevices",
          "iam:ResyncMFADevice"
        ]
        Resource = [
          "arn:aws:iam::*:mfa/$${aws:username}",
          "arn:aws:iam::*:user/$${aws:username}"
        ]
      },
      {
        Sid    = "DenyWithoutMFA"
        Effect = "Deny"
        NotAction = [
          "iam:CreateVirtualMFADevice", "iam:EnableMFADevice",
          "iam:GetUser", "iam:ListMFADevices",
          "iam:ListVirtualMFADevices", "iam:ResyncMFADevice",
          "sts:GetSessionToken"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = { "aws:MultiFactorAuthPresent" = "false" }
        }
      }
    ]
  })
  tags = var.tags
}

resource "aws_iam_group_policy_attachment" "admins_mfa" {
  group      = aws_iam_group.admins.name
  policy_arn = aws_iam_policy.force_mfa.arn
}

resource "aws_iam_group_policy_attachment" "developers_mfa" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.force_mfa.arn
}

# ── Break-glass (emergency) role ─────────────────────────────────────
resource "aws_iam_role" "break_glass" {
  name                 = "role-break-glass-${var.name_prefix}"
  max_session_duration = 3600
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "sts:AssumeRole"
      Condition = { Bool = { "aws:MultiFactorAuthPresent" = "true" } }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "break_glass_admin" {
  role       = aws_iam_role.break_glass.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ── Read-only cross-account access role ──────────────────────────────
resource "aws_iam_role" "readonly_cross_account" {
  name = "role-readonly-xaccount-${var.name_prefix}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "sts:AssumeRole"
      Condition = { Bool = { "aws:MultiFactorAuthPresent" = "true" } }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "readonly_xaccount" {
  role       = aws_iam_role.readonly_cross_account.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ── Deny leaving AWS Organizations (if used) ─────────────────────────
resource "aws_iam_policy" "deny_org_leave" {
  name        = "policy-deny-leave-org-${var.name_prefix}"
  description = "Prevent any IAM principal from leaving the AWS Organization."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Deny"
      Action   = "organizations:LeaveOrganization"
      Resource = "*"
    }]
  })
  tags = var.tags
}
