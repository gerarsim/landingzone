output "vpc_id" {
  value = google_compute_network.hub.id
}

output "vpc_name" {
  value = google_compute_network.hub.name
}

output "subnet_id" {
  value = google_compute_subnetwork.hub.id
}

output "landing_zone_summary" {
  value = {
    company        = var.company_name
    environment    = var.environment
    region         = var.region
    project_id     = var.project_id
    vpc_name       = google_compute_network.hub.name
    monthly_budget = var.monthly_budget
  }
}
