output "budget_id" {
  value       = aws_budgets_budget.monthly.id
  description = "ID of the monthly cost budget."
}

output "budget_name" {
  value       = aws_budgets_budget.monthly.name
  description = "Name of the monthly cost budget."
}
