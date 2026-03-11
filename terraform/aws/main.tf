# ═══════════════════════════════════════════════════════════════════
# LZForge — AWS Landing Zone Root
# Orchestrates: networking, security, identity, monitoring, budget
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

  default_tags {
    tags = local.tags
  }
}

data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.company_name}-${var.environment}"
  tags = {
    Environment = var.environment
    Company     = var.company_name
    ManagedBy   = "lzforge-terraform"
    Region      = var.region
  }
}

# ── Networking ────────────────────────────────────────────────────────
module "networking" {
  source             = "./modules/networking"
  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  log_retention_days = var.log_retention_days
  tags               = local.tags
}

# ── Security (KMS, CloudTrail, GuardDuty, Security Hub, Analyzer) ────
module "security" {
  source              = "./modules/security"
  name_prefix         = local.name_prefix
  enable_guardduty    = var.enable_guardduty
  enable_security_hub = var.enable_security_hub
  log_retention_days  = var.log_retention_days
  alert_email         = var.alert_email
  tags                = local.tags
}

# ── Identity (password policy, IAM groups, break-glass role) ─────────
module "identity" {
  source      = "./modules/identity"
  name_prefix = local.name_prefix
  tags        = local.tags
}

# ── Monitoring (SNS, CIS CloudWatch alarms, dashboard) ───────────────
module "monitoring" {
  source                    = "./modules/monitoring"
  name_prefix               = local.name_prefix
  alert_email               = var.alert_email
  kms_key_id                = module.security.kms_key_id
  cloudtrail_log_group_name = "/lzforge/${local.name_prefix}/cloudtrail"
  tags                      = local.tags
  depends_on                = [module.security]
}

# ── Budget ────────────────────────────────────────────────────────────
module "budget" {
  source         = "./modules/budget"
  name_prefix    = local.name_prefix
  monthly_budget = var.monthly_budget
  alert_email    = var.alert_email
}
