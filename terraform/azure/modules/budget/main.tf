# ═══════════════════════════════════════════════════════════════════
# MODULE: budget
# Deploys subscription-level budget with alert thresholds at:
#   50%, 75%, 90%, 100%, 110% (forecasted)
# ═══════════════════════════════════════════════════════════════════

resource "azurerm_consumption_budget_subscription" "main" {
  name            = "budget-${var.company_name}-${var.environment}"
  subscription_id = "/subscriptions/${var.subscription_id}"
  amount          = var.monthly_budget
  time_grain      = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00'Z'", timestamp())
  }

  # 50% actual
  notification {
    enabled        = true
    threshold      = 50
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }

  # 75% actual
  notification {
    enabled        = true
    threshold      = 75
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }

  # 90% actual
  notification {
    enabled        = true
    threshold      = 90
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }

  # 100% actual
  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }

  # 110% forecasted
  notification {
    enabled        = true
    threshold      = 110
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_emails = [var.alert_email]
  }
}
