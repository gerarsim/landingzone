# ═══════════════════════════════════════════════════════════════════
# LZForge — AWS Monitoring Module
# SNS alerts, CloudWatch metric filters + alarms for CIS benchmark
# controls (unauthorized API, root login, console MFA, etc.)
# ═══════════════════════════════════════════════════════════════════

# ── SNS topic for security alerts ────────────────────────────────────
resource "aws_sns_topic" "alerts" {
  name              = "lzforge-alerts-${var.name_prefix}"
  kms_master_key_id = var.kms_key_id
  tags              = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ── CloudWatch metric filters → alarms (CIS AWS Benchmark) ───────────

locals {
  # Each entry: [filter_name, pattern, alarm_name, alarm_description]
  cis_filters = [
    [
      "UnauthorizedAPICalls",
      "{ ($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\") }",
      "cis-unauthorized-api-calls",
      "CIS 3.1 — Unauthorized API calls detected"
    ],
    [
      "ConsoleSigninNoMFA",
      "{ ($.eventName = \"ConsoleLogin\") && ($.additionalEventData.MFAUsed != \"Yes\") && ($.responseElements.ConsoleLogin = \"Success\") && ($.additionalEventData.SamlProviderArn NOT EXISTS) }",
      "cis-console-signin-no-mfa",
      "CIS 3.2 — Console sign-in without MFA"
    ],
    [
      "RootAccountUsage",
      "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }",
      "cis-root-account-usage",
      "CIS 3.3 — Root account usage detected"
    ],
    [
      "IAMPolicyChanges",
      "{ ($.eventName=DeleteGroupPolicy) || ($.eventName=DeleteRolePolicy) || ($.eventName=DeleteUserPolicy) || ($.eventName=PutGroupPolicy) || ($.eventName=PutRolePolicy) || ($.eventName=PutUserPolicy) || ($.eventName=CreatePolicy) || ($.eventName=DeletePolicy) || ($.eventName=CreatePolicyVersion) || ($.eventName=DeletePolicyVersion) || ($.eventName=SetDefaultPolicyVersion) || ($.eventName=AttachRolePolicy) || ($.eventName=DetachRolePolicy) || ($.eventName=AttachUserPolicy) || ($.eventName=DetachUserPolicy) || ($.eventName=AttachGroupPolicy) || ($.eventName=DetachGroupPolicy) }",
      "cis-iam-policy-changes",
      "CIS 3.4 — IAM policy changes detected"
    ],
    [
      "CloudTrailConfigChanges",
      "{ ($.eventName = CreateTrail) || ($.eventName = UpdateTrail) || ($.eventName = DeleteTrail) || ($.eventName = StartLogging) || ($.eventName = StopLogging) }",
      "cis-cloudtrail-config-changes",
      "CIS 3.5 — CloudTrail configuration changes"
    ],
    [
      "ConsoleAuthFailures",
      "{ ($.eventName = ConsoleLogin) && ($.errorMessage = \"Failed authentication\") }",
      "cis-console-auth-failures",
      "CIS 3.6 — AWS Management Console authentication failures"
    ],
    [
      "CMKDisableOrDelete",
      "{ ($.eventSource = kms.amazonaws.com) && (($.eventName = DisableKey) || ($.eventName = ScheduleKeyDeletion)) }",
      "cis-cmk-disable-delete",
      "CIS 3.7 — KMS CMK disabled or scheduled for deletion"
    ],
    [
      "S3BucketPolicyChanges",
      "{ ($.eventSource = s3.amazonaws.com) && (($.eventName = PutBucketAcl) || ($.eventName = PutBucketPolicy) || ($.eventName = PutBucketCors) || ($.eventName = PutBucketLifecycle) || ($.eventName = PutBucketReplication) || ($.eventName = DeleteBucketPolicy) || ($.eventName = DeleteBucketCors) || ($.eventName = DeleteBucketLifecycle) || ($.eventName = DeleteBucketReplication)) }",
      "cis-s3-bucket-policy-changes",
      "CIS 3.8 — S3 bucket policy changes"
    ],
    [
      "AWSConfigChanges",
      "{ ($.eventSource = config.amazonaws.com) && (($.eventName = StopConfigurationRecorder) || ($.eventName = DeleteDeliveryChannel) || ($.eventName = PutDeliveryChannel) || ($.eventName = PutConfigurationRecorder)) }",
      "cis-aws-config-changes",
      "CIS 3.9 — AWS Config configuration changes"
    ],
    [
      "SecurityGroupChanges",
      "{ ($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = AuthorizeSecurityGroupEgress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupEgress) || ($.eventName = CreateSecurityGroup) || ($.eventName = DeleteSecurityGroup) }",
      "cis-sg-changes",
      "CIS 3.10 — Security group changes"
    ],
    [
      "NACLChanges",
      "{ ($.eventName = CreateNetworkAcl) || ($.eventName = CreateNetworkAclEntry) || ($.eventName = DeleteNetworkAcl) || ($.eventName = DeleteNetworkAclEntry) || ($.eventName = ReplaceNetworkAclEntry) || ($.eventName = ReplaceNetworkAclAssociation) }",
      "cis-nacl-changes",
      "CIS 3.11 — Network ACL changes"
    ],
    [
      "NetworkGatewayChanges",
      "{ ($.eventName = CreateCustomerGateway) || ($.eventName = DeleteCustomerGateway) || ($.eventName = AttachInternetGateway) || ($.eventName = CreateInternetGateway) || ($.eventName = DeleteInternetGateway) || ($.eventName = DetachInternetGateway) }",
      "cis-network-gateway-changes",
      "CIS 3.12 — Network gateway changes"
    ],
    [
      "RouteTableChanges",
      "{ ($.eventName = CreateRoute) || ($.eventName = CreateRouteTable) || ($.eventName = ReplaceRoute) || ($.eventName = ReplaceRouteTableAssociation) || ($.eventName = DeleteRouteTable) || ($.eventName = DeleteRoute) || ($.eventName = DisassociateRouteTable) }",
      "cis-route-table-changes",
      "CIS 3.13 — Route table changes"
    ],
    [
      "VPCChanges",
      "{ ($.eventName = CreateVpc) || ($.eventName = DeleteVpc) || ($.eventName = ModifyVpcAttribute) || ($.eventName = AcceptVpcPeeringConnection) || ($.eventName = CreateVpcPeeringConnection) || ($.eventName = DeleteVpcPeeringConnection) || ($.eventName = RejectVpcPeeringConnection) || ($.eventName = AttachClassicLinkVpc) || ($.eventName = DetachClassicLinkVpc) || ($.eventName = DisableVpcClassicLink) || ($.eventName = EnableVpcClassicLink) }",
      "cis-vpc-changes",
      "CIS 3.14 — VPC changes"
    ],
  ]
}

resource "aws_cloudwatch_log_metric_filter" "cis" {
  count          = length(local.cis_filters)
  name           = local.cis_filters[count.index][0]
  pattern        = local.cis_filters[count.index][1]
  log_group_name = var.cloudtrail_log_group_name

  metric_transformation {
    name      = local.cis_filters[count.index][0]
    namespace = "LZForge/CISBenchmark"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "cis" {
  count               = length(local.cis_filters)
  alarm_name          = local.cis_filters[count.index][2]
  alarm_description   = local.cis_filters[count.index][3]
  metric_name         = local.cis_filters[count.index][0]
  namespace           = "LZForge/CISBenchmark"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  tags                = var.tags
}

# ── CloudWatch Dashboard ──────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "lzforge-${var.name_prefix}"
  dashboard_body = jsonencode({
    widgets = [
      {
        type       = "metric"
        properties = {
          title   = "Unauthorized API Calls"
          metrics = [["LZForge/CISBenchmark", "UnauthorizedAPICalls"]]
          period  = 300
          stat    = "Sum"
          view    = "timeSeries"
        }
      },
      {
        type       = "metric"
        properties = {
          title   = "Root Account Usage"
          metrics = [["LZForge/CISBenchmark", "RootAccountUsage"]]
          period  = 300
          stat    = "Sum"
          view    = "timeSeries"
        }
      },
      {
        type       = "metric"
        properties = {
          title   = "Console Sign-in (no MFA)"
          metrics = [["LZForge/CISBenchmark", "ConsoleSigninNoMFA"]]
          period  = 300
          stat    = "Sum"
          view    = "timeSeries"
        }
      }
    ]
  })
}
