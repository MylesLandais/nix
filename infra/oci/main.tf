terraform {
  required_version = ">= 1.8.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.24.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid != "" ? var.user_ocid : null
  fingerprint      = var.fingerprint != "" ? var.fingerprint : null
  private_key_path = var.private_key_path != "" ? var.private_key_path : null
  region           = var.region
  auth             = var.auth != "" ? var.auth : "ApiKey"
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# ==============================================================================
# OCI Network Load Balancer (Layer 4 TCP Pass-Through)
# Always Free Eligible
# ==============================================================================
resource "oci_network_load_balancer_network_load_balancer" "forgejo_ssh" {
  compartment_id                 = var.compartment_ocid
  display_name                   = "forgejo-ssh-nlb"
  subnet_id                      = var.public_subnet_ocid
  is_private                     = false
  is_preserve_source_destination = false

  dynamic "reserved_ips" {
    for_each = var.reserved_ip_id != "" ? [var.reserved_ip_id] : []
    content {
      id = reserved_ips.value
    }
  }
}

# ==============================================================================
# Backend Set (Targeting Forgejo Go SSH Daemon on Port 2222)
# ==============================================================================
resource "oci_network_load_balancer_backend_set" "forgejo_ssh" {
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.forgejo_ssh.id
  name                     = "forgejo-ssh-backend"
  policy                   = "FIVE_TUPLE"

  # CRITICAL: Preserve Source IP MUST be false for backends in a private subnet
  # behind a NAT Gateway to prevent asymmetric routing drops.
  is_preserve_source = false

  health_checker {
    protocol           = "TCP"
    port               = 2222
    interval_in_millis = 10000
    timeout_in_millis  = 3000
    retries            = 3
  }
}

# ==============================================================================
# Backend (stage-db Instance Private IP)
# ==============================================================================
resource "oci_network_load_balancer_backend" "stage_db" {
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.forgejo_ssh.id
  backend_set_name         = oci_network_load_balancer_backend_set.forgejo_ssh.name
  ip_address               = var.stage_db_private_ip
  port                     = 2222
  weight                   = 1
}

# ==============================================================================
# Listener (Public Port 22 -> Backend Port 2222)
# ==============================================================================
resource "oci_network_load_balancer_listener" "forgejo_ssh" {
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.forgejo_ssh.id
  name                     = "forgejo-ssh-listener"
  default_backend_set_name = oci_network_load_balancer_backend_set.forgejo_ssh.name
  port                     = 22
  protocol                 = "TCP"
}

# ==============================================================================
# Cloudflare DNS (Unproxied / Grey-Cloud A-Record)
# ==============================================================================
locals {
  nlb_ip = try(
    [for ip in oci_network_load_balancer_network_load_balancer.forgejo_ssh.ip_addresses : ip.ip_address if ip.is_public][0],
    ""
  )
}

resource "cloudflare_dns_record" "forgejo_ssh" {
  count   = var.manage_cloudflare_dns ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "ssh"
  type    = "A"
  content = local.nlb_ip
  proxied = false # Direct TCP for SSH cannot be proxied by Cloudflare CDN
  ttl     = 1
}

# ==============================================================================
# OCI Security List (Optional: Open TCP:22 Public & TCP:2222 VCN Internal)
# ==============================================================================
resource "oci_core_security_list" "forgejo_ssh" {
  count          = var.manage_security_list ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_ocid
  display_name   = "forgejo-ssh-security-list"

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "Allow inbound SSH to Network Load Balancer"
    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = var.vcn_cidr
    description = "Allow VCN internal traffic to Forgejo SSH container"
    tcp_options {
      min = 2222
      max = 2222
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Allow all outbound traffic"
  }
}
