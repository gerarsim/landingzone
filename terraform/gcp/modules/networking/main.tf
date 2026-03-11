# ═══════════════════════════════════════════════════════════════════
# LZForge — GCP Networking Module
# VPC (custom mode), subnets with Private Google Access + flow logs,
# Cloud NAT, firewall rules (deny-all ingress, allow-IAP, allow-internal)
# ═══════════════════════════════════════════════════════════════════

# ── VPC (custom mode — no auto subnets) ──────────────────────────────
resource "google_compute_network" "hub" {
  name                    = "vpc-${var.name_prefix}-hub"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

# ── Primary subnet ────────────────────────────────────────────────────
resource "google_compute_subnetwork" "hub" {
  name                     = "snet-hub-${var.name_prefix}"
  ip_cidr_range            = var.subnet_cidr
  region                   = var.region
  network                  = google_compute_network.hub.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# ── Cloud Router ─────────────────────────────────────────────────────
resource "google_compute_router" "hub" {
  count   = var.enable_cloud_nat ? 1 : 0
  name    = "router-${var.name_prefix}"
  region  = var.region
  network = google_compute_network.hub.id

  bgp {
    asn            = 64514
    advertise_mode = "CUSTOM"
  }
}

# ── Cloud NAT ────────────────────────────────────────────────────────
resource "google_compute_router_nat" "hub" {
  count                              = var.enable_cloud_nat ? 1 : 0
  name                               = "nat-${var.name_prefix}"
  router                             = google_compute_router.hub[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ── Firewall rules ────────────────────────────────────────────────────

# Deny all ingress (lowest priority — explicit deny)
resource "google_compute_firewall" "deny_all_ingress" {
  name      = "fw-deny-all-ingress-${var.name_prefix}"
  network   = google_compute_network.hub.id
  direction = "INGRESS"
  priority  = 65534

  deny { protocol = "all" }
  source_ranges = ["0.0.0.0/0"]
}

# Allow internal VPC traffic
resource "google_compute_firewall" "allow_internal" {
  name      = "fw-allow-internal-${var.name_prefix}"
  network   = google_compute_network.hub.id
  direction = "INGRESS"
  priority  = 1000

  allow { protocol = "tcp" }
  allow { protocol = "udp" }
  allow { protocol = "icmp" }
  source_ranges = [var.subnet_cidr]
}

# Allow IAP (Identity-Aware Proxy) for SSH/RDP tunnelling
resource "google_compute_firewall" "allow_iap" {
  name      = "fw-allow-iap-${var.name_prefix}"
  network   = google_compute_network.hub.id
  direction = "INGRESS"
  priority  = 900

  allow {
    protocol = "tcp"
    ports    = ["22", "3389"]
  }
  source_ranges = ["35.235.240.0/20"] # IAP CIDR
}

# Allow health-check probes (GCP load balancers)
resource "google_compute_firewall" "allow_health_checks" {
  name      = "fw-allow-health-checks-${var.name_prefix}"
  network   = google_compute_network.hub.id
  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"] # GCP health-check ranges
  target_tags   = ["allow-health-check"]
}

# Deny egress to GCP metadata server from non-GCE resources
resource "google_compute_firewall" "deny_metadata_egress" {
  name      = "fw-deny-metadata-egress-${var.name_prefix}"
  network   = google_compute_network.hub.id
  direction = "EGRESS"
  priority  = 800

  deny { protocol = "tcp" }
  destination_ranges = ["169.254.169.254/32"]
  target_tags        = ["deny-metadata"]
}
