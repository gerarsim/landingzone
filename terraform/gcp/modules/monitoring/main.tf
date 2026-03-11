# ═══════════════════════════════════════════════════════════════════
# LZForge — GCP Monitoring Module
# Log sink → GCS bucket, Cloud Monitoring notification channel,
# alerting policies (IAM changes, firewall changes, audit log errors,
# budget, uptime), Log-based metrics
# ═══════════════════════════════════════════════════════════════════

data "google_project" "current" {}

# ── Enable required APIs ──────────────────────────────────────────────
resource "google_project_service" "monitoring_apis" {
  for_each           = toset(["monitoring.googleapis.com", "logging.googleapis.com"])
  service            = each.value
  disable_on_destroy = false
}

# ── GCS bucket for audit log sink ────────────────────────────────────
resource "google_storage_bucket" "audit_logs" {
  name                        = "lzforge-audit-${var.name_prefix}-${data.google_project.current.number}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false

  lifecycle_rule {
    action { type = "SetStorageClass"; storage_class = "NEARLINE" }
    condition { age = 90 }
  }
  lifecycle_rule {
    action { type = "SetStorageClass"; storage_class = "COLDLINE" }
    condition { age = 365 }
  }
  lifecycle_rule {
    action { type = "Delete" }
    condition { age = 2557 } # 7 years
  }

  retention_policy {
    is_locked        = false
    retention_period = 31536000 # 1 year minimum
  }
}

# ── Log sink → GCS ────────────────────────────────────────────────────
resource "google_logging_project_sink" "audit" {
  name                   = "sink-audit-${var.name_prefix}"
  destination            = "storage.googleapis.com/${google_storage_bucket.audit_logs.name}"
  filter                 = "logName:(\"cloudaudit.googleapis.com\" OR \"activity\" OR \"data_access\")"
  unique_writer_identity = true
}

resource "google_storage_bucket_iam_member" "audit_sink_writer" {
  bucket = google_storage_bucket.audit_logs.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.audit.writer_identity
}

# ── Notification channel (email) ─────────────────────────────────────
resource "google_monitoring_notification_channel" "email" {
  display_name = "LZForge Alerts — ${var.name_prefix}"
  type         = "email"
  labels       = { email_address = var.alert_email }
}

# ── Log-based metrics ─────────────────────────────────────────────────

locals {
  log_metrics = {
    iam_changes = {
      description = "IAM policy changes"
      filter      = "resource.type=\"project\" AND (protoPayload.methodName=\"SetIamPolicy\" OR protoPayload.methodName=\"google.iam.v1.IAMPolicy.SetIamPolicy\")"
    }
    firewall_changes = {
      description = "Firewall rule changes"
      filter      = "resource.type=\"gce_firewall_rule\" AND jsonPayload.event_subtype=(\"compute.firewalls.insert\" OR \"compute.firewalls.patch\" OR \"compute.firewalls.delete\")"
    }
    project_ownership = {
      description = "Project ownership assignments"
      filter      = "resource.type=\"project\" AND protoPayload.serviceName=\"cloudresourcemanager.googleapis.com\" AND ProjectOwnership OR protoPayload.serviceData.policyDelta.bindingDeltas.action=(\"ADD\" OR \"REMOVE\") AND protoPayload.serviceData.policyDelta.bindingDeltas.role=\"roles/owner\""
    }
    audit_log_config_changes = {
      description = "Audit log configuration changes"
      filter      = "protoPayload.methodName=\"SetIamPolicy\" AND protoPayload.serviceData.policyDelta.auditConfigDeltas:*"
    }
    custom_role_changes = {
      description = "Custom IAM role changes"
      filter      = "resource.type=\"iam_role\" AND protoPayload.methodName=(\"google.iam.admin.v1.CreateRole\" OR \"google.iam.admin.v1.DeleteRole\" OR \"google.iam.admin.v1.UpdateRole\")"
    }
    vpc_network_changes = {
      description = "VPC network and route changes"
      filter      = "resource.type=\"gce_network\" AND jsonPayload.event_subtype=(\"compute.networks.insert\" OR \"compute.networks.patch\" OR \"compute.networks.delete\" OR \"compute.routes.delete\" OR \"compute.routes.insert\")"
    }
    storage_iam_changes = {
      description = "GCS bucket IAM permission changes"
      filter      = "resource.type=\"gcs_bucket\" AND protoPayload.methodName=\"storage.setIamPermissions\""
    }
    sql_instance_changes = {
      description = "Cloud SQL instance changes"
      filter      = "protoPayload.methodName=\"cloudsql.instances.update\""
    }
  }
}

resource "google_logging_metric" "security" {
  for_each    = local.log_metrics
  name        = "lzforge/${var.name_prefix}/${each.key}"
  description = each.value.description
  filter      = each.value.filter

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

# ── Alerting policies ─────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "iam_changes" {
  display_name          = "[LZForge] IAM Policy Changes — ${var.name_prefix}"
  combiner              = "OR"
  notification_channels = [google_monitoring_notification_channel.email.id]

  conditions {
    display_name = "IAM policy change detected"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/lzforge/${var.name_prefix}/iam_changes\" AND resource.type=\"project\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  depends_on = [google_logging_metric.security]
}

resource "google_monitoring_alert_policy" "firewall_changes" {
  display_name          = "[LZForge] Firewall Rule Changes — ${var.name_prefix}"
  combiner              = "OR"
  notification_channels = [google_monitoring_notification_channel.email.id]

  conditions {
    display_name = "Firewall rule change detected"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/lzforge/${var.name_prefix}/firewall_changes\" AND resource.type=\"gce_firewall_rule\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  depends_on = [google_logging_metric.security]
}

resource "google_monitoring_alert_policy" "project_ownership" {
  display_name          = "[LZForge] Project Ownership Change — ${var.name_prefix}"
  combiner              = "OR"
  notification_channels = [google_monitoring_notification_channel.email.id]

  conditions {
    display_name = "Owner role assigned or removed"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/lzforge/${var.name_prefix}/project_ownership\" AND resource.type=\"project\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  depends_on = [google_logging_metric.security]
}
