# ═══════════════════════════════════════════════════════════════════
# VELOX — Root Outputs
# Aggregated outputs from all modules — written to Terraform state
# and surfaced in the Velox UI after a successful provision.
# ═══════════════════════════════════════════════════════════════════

# ── Management Groups ─────────────────────────────────────────────────
output "management_group_ids" {
  description = "Full map of all management group IDs in the hierarchy."
  value       = module.management_groups.all_mg_ids
}

# ── Networking ────────────────────────────────────────────────────────
output "hub_vnet_id" {
  description = "Resource ID of the hub virtual network."
  value       = module.networking.hub_vnet_id
}

output "spoke_vnet_ids" {
  description = "Map of spoke name → resource ID."
  value       = module.networking.spoke_vnet_ids
}

output "resource_groups" {
  description = "Names of the three core resource groups (networking, security, ops)."
  value       = module.networking.resource_group_names
}

output "firewall_private_ip" {
  description = "Private IP of Azure Firewall (null if not deployed)."
  value       = module.networking.firewall_private_ip
}

output "bastion_public_ip" {
  description = "Public IP of Azure Bastion (null if not deployed)."
  value       = module.networking.bastion_public_ip
}

output "private_dns_zone_id" {
  description = "Resource ID of the private DNS zone (<company>.internal)."
  value       = module.networking.private_dns_zone_id
}

# ── Monitoring ────────────────────────────────────────────────────────
output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace resource ID."
  value       = module.monitoring.workspace_id
}

output "log_analytics_workspace_name" {
  description = "Log Analytics Workspace name."
  value       = module.monitoring.workspace_name
}

output "diagnostics_storage_account_id" {
  description = "Storage account ID used for diagnostic log archival."
  value       = module.monitoring.storage_account_id
}

# ── Security ──────────────────────────────────────────────────────────
output "key_vault_id" {
  description = "Resource ID of the landing-zone Key Vault."
  value       = module.security.key_vault_id
}

output "key_vault_uri" {
  description = "URI of the landing-zone Key Vault."
  value       = module.security.key_vault_uri
}

output "key_vault_name" {
  description = "Name of the landing-zone Key Vault."
  value       = module.security.key_vault_name
}

output "defender_plans_enabled" {
  description = "Set of Microsoft Defender plans enabled on this subscription."
  value       = module.security.defender_plans_enabled
}

# ── Identity ──────────────────────────────────────────────────────────
output "aad_group_ids" {
  description = "Map of AAD security group names → object IDs."
  value       = module.identity.aad_group_ids
}

output "lz_operator_role_id" {
  description = "Resource ID of the custom LZ Operator RBAC role."
  value       = module.identity.lz_operator_role_id
}

# ── Policies ─────────────────────────────────────────────────────────
output "policy_assignments" {
  description = "Map of policy assignment names → resource IDs."
  value       = module.policies.assignments
}

# ── Budget ────────────────────────────────────────────────────────────
output "budget_id" {
  description = "Resource ID of the subscription consumption budget."
  value       = module.budget.budget_id
}

output "budget_amount" {
  description = "Configured monthly budget amount (USD)."
  value       = module.budget.budget_amount
}

# ── Summary ───────────────────────────────────────────────────────────
output "landing_zone_summary" {
  description = "High-level summary of the provisioned landing zone."
  value = {
    company        = var.company_name
    environment    = var.environment
    location       = var.location
    key_vault      = module.security.key_vault_name
    log_analytics  = module.monitoring.workspace_name
    hub_vnet       = module.networking.hub_vnet_name
    monthly_budget = var.monthly_budget
  }
}
