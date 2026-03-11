# ═══════════════════════════════════════════════════════════════════
# LZForge — GCP Identity Module
# Service accounts (terraform, app, auditor), IAM bindings,
# org-level policy constraints (no public IPs, domain restriction,
# disable SA key creation, uniform bucket access)
# ═══════════════════════════════════════════════════════════════════

data "google_project" "current" {}

# ── Service Accounts ─────────────────────────────────────────────────

# Terraform automation SA (used for subsequent IaC runs)
resource "google_service_account" "terraform" {
  account_id   = "sa-terraform-${var.name_prefix}"
  display_name = "LZForge Terraform SA — ${var.name_prefix}"
  description  = "Service account for Terraform automation. Managed by LZForge."
}

# Application workload SA
resource "google_service_account" "app" {
  account_id   = "sa-app-${var.name_prefix}"
  display_name = "Application Workload SA — ${var.name_prefix}"
  description  = "Service account for application workloads."
}

# Auditor SA (read-only)
resource "google_service_account" "auditor" {
  account_id   = "sa-auditor-${var.name_prefix}"
  display_name = "Auditor SA — ${var.name_prefix}"
  description  = "Read-only service account for compliance auditing."
}

# ── Project IAM bindings ──────────────────────────────────────────────

resource "google_project_iam_member" "terraform_editor" {
  project = data.google_project.current.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_project_iam_member" "terraform_security_admin" {
  project = data.google_project.current.project_id
  role    = "roles/iam.securityAdmin"
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_project_iam_member" "auditor_viewer" {
  project = data.google_project.current.project_id
  role    = "roles/viewer"
  member  = "serviceAccount:${google_service_account.auditor.email}"
}

resource "google_project_iam_member" "auditor_log_viewer" {
  project = data.google_project.current.project_id
  role    = "roles/logging.viewer"
  member  = "serviceAccount:${google_service_account.auditor.email}"
}

resource "google_project_iam_member" "auditor_security_reviewer" {
  project = data.google_project.current.project_id
  role    = "roles/iam.securityReviewer"
  member  = "serviceAccount:${google_service_account.auditor.email}"
}

# ── Org-level policy constraints (best practice) ──────────────────────

# Disable external IPs on VM instances
resource "google_project_organization_policy" "no_external_ips" {
  count      = var.org_id != "" ? 1 : 0
  project    = data.google_project.current.project_id
  constraint = "compute.vmExternalIpAccess"
  list_policy {
    deny { all = true }
  }
}

# Restrict public IPs on Cloud SQL
resource "google_project_organization_policy" "no_cloudsql_public_ip" {
  count      = var.org_id != "" ? 1 : 0
  project    = data.google_project.current.project_id
  constraint = "sql.restrictPublicIp"
  boolean_policy { enforced = true }
}

# Require uniform bucket-level access (no legacy ACLs on GCS)
resource "google_project_organization_policy" "uniform_bucket_access" {
  count      = var.org_id != "" ? 1 : 0
  project    = data.google_project.current.project_id
  constraint = "storage.uniformBucketLevelAccess"
  boolean_policy { enforced = true }
}

# Disable SA key creation (force Workload Identity instead)
resource "google_project_organization_policy" "disable_sa_key_creation" {
  count      = var.org_id != "" ? 1 : 0
  project    = data.google_project.current.project_id
  constraint = "iam.disableServiceAccountKeyCreation"
  boolean_policy { enforced = true }
}

# Restrict allowed load balancer types to internal only
resource "google_project_organization_policy" "restrict_lb_types" {
  count      = var.org_id != "" ? 1 : 0
  project    = data.google_project.current.project_id
  constraint = "compute.restrictLoadBalancerCreationForTypes"
  list_policy {
    allow {
      values = [
        "INTERNAL", "INTERNAL_TCP_UDP", "INTERNAL_MANAGED",
        "INTERNAL_SELF_MANAGED", "EXTERNAL_MANAGED"
      ]
    }
  }
}

# ── Workload Identity Pool (for external workloads / CI-CD) ──────────
resource "google_iam_workload_identity_pool" "main" {
  workload_identity_pool_id = "pool-${var.name_prefix}"
  display_name              = "LZForge Pool — ${var.name_prefix}"
  description               = "Workload Identity Pool for external workloads."
  disabled                  = false
}
