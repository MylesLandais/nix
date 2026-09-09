output "tunnel_id" {
  value = cloudflare_zero_trust_tunnel_cloudflared.lumen.id
}

output "hostname" {
  value = var.domain
}
