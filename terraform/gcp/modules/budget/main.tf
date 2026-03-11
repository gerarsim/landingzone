# ═══════════════════════════════════════════════════════════════════
# LZForge — GCP Budget Module
# Billing budget with 50 / 75 / 90 / 100 / 110 % thresholds,
# Pub/Sub topic for programmatic alerts, email notification
# ═══════════════════════════════════════════════════════════════════

# ── Pub/Sub topic for budget alerts ──────────────────────────────────
resource "google_pubsub_topic" "budget_alerts" {
  name = "budget-alerts-${var.name_prefix}"

  message_retention_duration = "86400s" # 24 hours
}

# Allow Cloud Billing to publish to the topic
resource "google_pubsub_topic_iam_member" "billing_publisher" {
  topic  = google_pubsub_topic.budget_alerts.id
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:billing-export-pubsub@system.gserviceaccount.com"
}

# ── Billing budget ────────────────────────────────────────────────────
resource "google_billing_budget" "main" {
  count           = var.billing_account_id != "" ? 1 : 0
  billing_account = var.billing_account_id
  display_name    = "budget-${var.name_prefix}"

  budget_filter {
    projects               = ["projects/${var.project_number}"]
    credit_types_treatment = "INCLUDE_ALL_CREDITS"
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.monthly_budget)
    }
  }

  threshold_rules { threshold_percent = 0.5  spend_basis = "CURRENT_SPEND" }
  threshold_rules { threshold_percent = 0.75 spend_basis = "CURRENT_SPEND" }
  threshold_rules { threshold_percent = 0.9  spend_basis = "CURRENT_SPEND" }
  threshold_rules { threshold_percent = 1.0  spend_basis = "CURRENT_SPEND" }
  threshold_rules { threshold_percent = 1.0  spend_basis = "FORECASTED_SPEND" }
  threshold_rules { threshold_percent = 1.1  spend_basis = "CURRENT_SPEND" }

  all_updates_rule {
    pubsub_topic                     = google_pubsub_topic.budget_alerts.id
    schema_version                   = "1.0"
    monitoring_notification_channels = var.notification_channel_ids
    disable_default_iam_recipients   = false
  }
}

# ── Pub/Sub subscription → Cloud Function (optional webhook) ─────────
resource "google_pubsub_subscription" "budget_alerts" {
  name  = "sub-budget-alerts-${var.name_prefix}"
  topic = google_pubsub_topic.budget_alerts.id

  ack_deadline_seconds       = 60
  message_retention_duration = "86400s"
  retain_acked_messages      = false

  expiration_policy { ttl = "" } # never expires
}
