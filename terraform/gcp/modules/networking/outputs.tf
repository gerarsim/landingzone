output "vpc_id" {
  value       = google_compute_network.hub.id
  description = "VPC network ID."
}

output "vpc_name" {
  value       = google_compute_network.hub.name
  description = "VPC network name."
}

output "subnet_id" {
  value       = google_compute_subnetwork.hub.id
  description = "Primary subnet ID."
}

output "subnet_name" {
  value       = google_compute_subnetwork.hub.name
  description = "Primary subnet name."
}

output "nat_router_name" {
  value       = var.enable_cloud_nat ? google_compute_router.hub[0].name : ""
  description = "Cloud Router name."
}
