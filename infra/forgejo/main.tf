terraform {
  required_version = ">= 1.8.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.24.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
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

resource "random_password" "tunnel_secret" {
  length  = 32
  special = false
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "forgejo" {
  account_id    = var.cloudflare_account_id
  name          = "nebula-1-forgejo"
  config_src    = "cloudflare"
  tunnel_secret = random_password.tunnel_secret.result
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "forgejo" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.forgejo.id
  source     = "cloudflare"
  config = {
    ingress = [
      { hostname = var.domain, service = "http://forgejo:3000" },
      { service = "http_status:404" }
    ]
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "forgejo" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.forgejo.id
}

resource "cloudflare_dns_record" "forgejo" {
  zone_id = var.cloudflare_zone_id
  name    = "git"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.forgejo.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "local_sensitive_file" "docker_env" {
  filename        = "${path.module}/.env.tf"
  file_permission = "0600"
  content = templatefile("${path.module}/docker.env.tftpl", {
    domain       = var.domain
    tunnel_token = data.cloudflare_zero_trust_tunnel_cloudflared_token.forgejo.token
  })
}
