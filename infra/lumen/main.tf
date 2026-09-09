terraform {
  required_version = ">= 1.8.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.24.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "lumen" {
  account_id = var.cloudflare_account_id
  name       = "nebula-1-lumen"
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "lumen" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.lumen.id
  source     = "cloudflare"
  config = {
    ingress = [
      { hostname = var.domain, service = "http://127.0.0.1:80" },
      { service = "http_status:404" }
    ]
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "lumen" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.lumen.id
}

resource "cloudflare_dns_record" "lumen" {
  zone_id = var.cloudflare_zone_id
  name    = "cinemaya"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.lumen.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "local_sensitive_file" "tunnel_env" {
  filename        = "${path.module}/.env.tunnel"
  file_permission = "0600"
  content = templatefile("${path.module}/tunnel.env.tftpl", {
    tunnel_token = data.cloudflare_zero_trust_tunnel_cloudflared_token.lumen.token
  })
}
