# ═══════════════════════════════════════════════════════════════════
# LZForge — GCP Security Module
# Cloud KMS, Secret Manager, Cloud Armor WAF, data access audit logs,
# org policy constraints, VPC Service Controls perimeter
# ═══════════════════════════════════════════════════════════════════

data "google_project" "current" {}

# ── Cloud KMS key ring + key ──────────────────────────────────────────
resource "google_kms_key_ring" "main" {
  name     = "keyring-${var.name_prefix}"
  location = var.region
}

resource "google_kms_crypto_key" "main" {
  name            = "key-${var.name_prefix}"
  key_ring        = google_kms_key_ring.main.id
  rotation_period = "7776000s" # 90 days

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "SOFTWARE"
  }

  lifecycle {
    prevent_destroy = false # set true in prod
  }
}

# Allow Compute Engine default SA to use the key (for disk encryption)
resource "google_kms_crypto_key_iam_binding" "compute_encrypter" {
  crypto_key_id = google_kms_crypto_key.main.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  members = [
    "serviceAccount:service-${data.google_project.current.number}@compute-system.iam.gserviceaccount.com",
  ]
}

# ── Secret Manager ────────────────────────────────────────────────────
resource "google_project_service" "secretmanager" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# Bootstrap secret for LZ metadata
resource "google_secret_manager_secret" "lz_metadata" {
  secret_id = "lz-metadata-${var.name_prefix}"
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "lz_metadata" {
  secret = google_secret_manager_secret.lz_metadata.id
  secret_data = jsonencode({
    company     = split("-", var.name_prefix)[0]
    environment = split("-", var.name_prefix)[1]
    managed_by  = "lzforge-terraform"
  })
}

# ── Cloud Armor WAF security policy ──────────────────────────────────
resource "google_compute_security_policy" "waf" {
  count = var.enable_cloud_armor ? 1 : 0
  name  = "waf-${var.name_prefix}"

  # OWASP Top 10 pre-configured rules
  rule {
    action   = "deny(403)"
    priority = 1000
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-v33-stable')"
      }
    }
    description = "Block XSS attacks"
  }

  rule {
    action   = "deny(403)"
    priority = 1001
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-v33-stable')"
      }
    }
    description = "Block SQL injection attacks"
  }

  rule {
    action   = "deny(403)"
    priority = 1002
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rce-v33-stable')"
      }
    }
    description = "Block remote code execution"
  }

  rule {
    action   = "deny(403)"
    priority = 1003
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-v33-stable')"
      }
    }
    description = "Block local file inclusion"
  }

  # Rate limiting — 1000 req/min per IP
  rule {
    action   = "throttle"
    priority = 2000
    match {
      versioned_expr = "SRC_IPS_V1"
      config { src_ip_ranges = ["*"] }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 1000
        interval_sec = 60
      }
    }
    description = "Rate limit: 1000 req/min per IP"
  }

  # Default allow
  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config { src_ip_ranges = ["*"] }
    }
    description = "Default allow"
  }
}

# ── Data access audit log configuration ──────────────────────────────
resource "google_project_iam_audit_config" "all_services" {
  project = data.google_project.current.project_id
  service = "allServices"

  audit_log_config { log_type = "ADMIN_READ" }
  audit_log_config { log_type = "DATA_READ" }
  audit_log_config { log_type = "DATA_WRITE" }
}

# ── Enable essential security APIs ────────────────────────────────────
locals {
  security_apis = [
    "cloudkms.googleapis.com",
    "cloudasset.googleapis.com",
    "securitycenter.googleapis.com",
    "containerscanning.googleapis.com",
    "binaryauthorization.googleapis.com",
  ]
}

resource "google_project_service" "security_apis" {
  for_each           = toset(local.security_apis)
  service            = each.value
  disable_on_destroy = false
}
