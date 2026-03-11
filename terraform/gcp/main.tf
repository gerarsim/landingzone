# ═══════════════════════════════════════════════════════════════════
# LZForge — GCP Landing Zone Root
# Orchestrates: networking, security, identity, monitoring, budget
# ═══════════════════════════════════════════════════════════════════

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "current" {}

locals {
  name_prefix = "${var.company_name}-${var.environment}"
  labels = {
    environment = var.environment
    company     = var.company_name
    managed_by  = "lzforge-terraform"
  }
}

# ── Enable core APIs ──────────────────────────────────────────────────
resource "google_project_service" "core_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "billingbudgets.googleapis.com",
    "pubsub.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudkms.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}

# ── Networking ────────────────────────────────────────────────────────
module "networking" {
  source           = "./modules/networking"
  name_prefix      = local.name_prefix
  region           = var.region
  subnet_cidr      = var.subnet_cidr
  enable_cloud_nat = var.enable_cloud_nat
  depends_on       = [google_project_service.core_apis]
}

# ── Security (KMS, Secret Manager, Cloud Armor, audit logs) ──────────
module "security" {
  source              = "./modules/security"
  name_prefix         = local.name_prefix
  region              = var.region
  enable_cloud_armor  = var.enable_cloud_armor
  enable_scc          = var.enable_scc
  depends_on          = [google_project_service.core_apis]
}

# ── Identity (service accounts, IAM, org policies) ────────────────────
module "identity" {
  source      = "./modules/identity"
  name_prefix = local.name_prefix
  org_id      = var.org_id
  depends_on  = [google_project_service.core_apis]
}

# ── Monitoring (log sink, alerting policies, metrics) ─────────────────
module "monitoring" {
  source      = "./modules/monitoring"
  name_prefix = local.name_prefix
  region      = var.region
  alert_email = var.alert_email
  depends_on  = [google_project_service.core_apis]
}

# ── Budget ────────────────────────────────────────────────────────────
module "budget" {
  source                   = "./modules/budget"
  name_prefix              = local.name_prefix
  monthly_budget           = var.monthly_budget
  billing_account_id       = var.billing_account_id
  project_number           = data.google_project.current.number
  notification_channel_ids = [module.monitoring.notification_channel_id]
  depends_on               = [module.monitoring]
}
