# ═══════════════════════════════════════════════════════════════════
# LZForge — GCP Landing Zone
# Provisions: VPC, Cloud NAT, IAM, Cloud Armor, Audit Logs, Budgets
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

locals {
  labels = {
    environment = var.environment
    company     = var.company_name
    managed_by  = "lzforge-terraform"
  }
}

# ── VPC ──────────────────────────────────────────────────────────────
resource "google_compute_network" "hub" {
  name                    = "vpc-${var.company_name}-hub-${var.environment}"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "hub" {
  name                     = "snet-hub-${var.environment}"
  ip_cidr_range            = var.subnet_cidr
  region                   = var.region
  network                  = google_compute_network.hub.id
  private_ip_google_access = true
}

# ── Firewall: deny all ingress, allow internal ────────────────────────
resource "google_compute_firewall" "deny_ingress" {
  name      = "fw-deny-ingress-${var.environment}"
  network   = google_compute_network.hub.id
  direction = "INGRESS"
  priority  = 65534
  deny { protocol = "all" }
  source_ranges = []
}

resource "google_compute_firewall" "allow_internal" {
  name      = "fw-allow-internal-${var.environment}"
  network   = google_compute_network.hub.id
  direction = "INGRESS"
  priority  = 1000
  allow { protocol = "all" }
  source_ranges = [var.subnet_cidr]
}

# ── Cloud NAT ────────────────────────────────────────────────────────
resource "google_compute_router" "hub" {
  count   = var.enable_cloud_nat ? 1 : 0
  name    = "router-${var.company_name}-${var.environment}"
  region  = var.region
  network = google_compute_network.hub.id
}

resource "google_compute_router_nat" "hub" {
  count                              = var.enable_cloud_nat ? 1 : 0
  name                               = "nat-${var.company_name}-${var.environment}"
  router                             = google_compute_router.hub[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# ── Cloud Armor WAF ───────────────────────────────────────────────────
resource "google_compute_security_policy" "waf" {
  count = var.enable_cloud_armor ? 1 : 0
  name  = "waf-${var.company_name}-${var.environment}"

  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config { src_ip_ranges = ["*"] }
    }
    description = "Default allow rule"
  }
}

# ── Budget Alert ──────────────────────────────────────────────────────
resource "google_pubsub_topic" "budget_alerts" {
  count = var.billing_account_id != "" ? 1 : 0
  name  = "budget-alerts-${var.company_name}-${var.environment}"
}

resource "google_billing_budget" "main" {
  count           = var.billing_account_id != "" ? 1 : 0
  billing_account = var.billing_account_id
  display_name    = "budget-${var.company_name}-${var.environment}"

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.monthly_budget)
    }
  }

  threshold_rules {
    threshold_percent = 0.9
  }

  all_updates_rule {
    pubsub_topic = google_pubsub_topic.budget_alerts[0].id
  }
}
