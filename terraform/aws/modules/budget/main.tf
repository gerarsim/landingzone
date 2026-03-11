# ═══════════════════════════════════════════════════════════════════
# LZForge — AWS Budget Module
# Cost budget with 50 / 75 / 90 / 100 / 110 % thresholds
# + forecasted spend alert at 100%
# ═══════════════════════════════════════════════════════════════════

resource "aws_budgets_budget" "monthly" {
  name         = "budget-${var.name_prefix}"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = [
      { pct = 50,  type = "ACTUAL"    },
      { pct = 75,  type = "ACTUAL"    },
      { pct = 90,  type = "ACTUAL"    },
      { pct = 100, type = "ACTUAL"    },
      { pct = 100, type = "FORECASTED" },
      { pct = 110, type = "ACTUAL"    },
    ]
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value.pct
      threshold_type             = "PERCENTAGE"
      notification_type          = notification.value.type
      subscriber_email_addresses = [var.alert_email]
    }
  }
}

# ── Per-service cost budgets for top spenders ─────────────────────────
locals {
  service_budgets = [
    { name = "ec2",    service = "Amazon Elastic Compute Cloud - Compute", pct = 40 },
    { name = "rds",    service = "Amazon Relational Database Service",     pct = 20 },
    { name = "s3",     service = "Amazon Simple Storage Service",          pct = 10 },
    { name = "lambda", service = "AWS Lambda",                             pct = 10 },
  ]
}

resource "aws_budgets_budget" "per_service" {
  count        = length(local.service_budgets)
  name         = "budget-${local.service_budgets[count.index].name}-${var.name_prefix}"
  budget_type  = "COST"
  limit_amount = tostring(floor(var.monthly_budget * local.service_budgets[count.index].pct / 100))
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "Service"
    values = [local.service_budgets[count.index].service]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 90
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
}
