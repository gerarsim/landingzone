# ═══════════════════════════════════════════════════════════════════
# LZForge — AWS Landing Zone
# Provisions: VPC, subnets, GuardDuty, CloudTrail, Security Hub,
#             S3 audit bucket, Budgets alert
# ═══════════════════════════════════════════════════════════════════

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" { state = "available" }

locals {
  account_id = data.aws_caller_identity.current.account_id
  tags = {
    Environment = var.environment
    Company     = var.company_name
    ManagedBy   = "lzforge-terraform"
  }
}

# ── VPC ──────────────────────────────────────────────────────────────
resource "aws_vpc" "hub" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(local.tags, { Name = "vpc-${var.company_name}-hub-${var.environment}" })
}

resource "aws_internet_gateway" "hub" {
  vpc_id = aws_vpc.hub.id
  tags   = merge(local.tags, { Name = "igw-${var.company_name}-${var.environment}" })
}

# ── Subnets (2 AZs) ──────────────────────────────────────────────────
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.hub.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags = merge(local.tags, { Name = "snet-public-${count.index}-${var.environment}" })
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.hub.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = merge(local.tags, { Name = "snet-private-${count.index}-${var.environment}" })
}

# ── Route table (public) ─────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.hub.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hub.id
  }
  tags = merge(local.tags, { Name = "rt-public-${var.environment}" })
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── GuardDuty ────────────────────────────────────────────────────────
resource "aws_guardduty_detector" "main" {
  count  = var.enable_guardduty ? 1 : 0
  enable = true
  tags   = local.tags
}

# ── CloudTrail ───────────────────────────────────────────────────────
resource "aws_s3_bucket" "cloudtrail" {
  count         = var.enable_cloudtrail ? 1 : 0
  bucket        = "ct-${var.company_name}-${var.environment}-${local.account_id}"
  force_destroy = true
  tags          = local.tags
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  count                   = var.enable_cloudtrail ? 1 : 0
  bucket                  = aws_s3_bucket.cloudtrail[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = "arn:aws:s3:::${aws_s3_bucket.cloudtrail[0].id}"
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "arn:aws:s3:::${aws_s3_bucket.cloudtrail[0].id}/AWSLogs/${local.account_id}/*"
        Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
      }
    ]
  })
}

resource "aws_cloudtrail" "main" {
  count                         = var.enable_cloudtrail ? 1 : 0
  name                          = "trail-${var.company_name}-${var.environment}"
  s3_bucket_name                = aws_s3_bucket.cloudtrail[0].id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  tags                          = local.tags
  depends_on                    = [aws_s3_bucket_policy.cloudtrail]
}

# ── Security Hub ─────────────────────────────────────────────────────
resource "aws_securityhub_account" "main" {
  count = var.enable_security_hub ? 1 : 0
}

# ── Budget ───────────────────────────────────────────────────────────
resource "aws_budgets_budget" "main" {
  name              = "budget-${var.company_name}-${var.environment}"
  budget_type       = "COST"
  limit_amount      = tostring(var.monthly_budget)
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2024-01-01_00:00"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 90
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
}
