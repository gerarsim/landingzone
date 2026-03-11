output "vpc_id" {
  value = aws_vpc.hub.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "landing_zone_summary" {
  value = {
    company        = var.company_name
    environment    = var.environment
    region         = var.region
    account_id     = data.aws_caller_identity.current.account_id
    vpc_id         = aws_vpc.hub.id
    monthly_budget = var.monthly_budget
  }
}
