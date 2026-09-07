output "tunnel_id" {
  value = cloudflare_zero_trust_tunnel_cloudflared.forgejo.id
}
output "hostname" {
  value = cloudflare_dns_record.forgejo.name
}
output "env_file" {
  value = local_sensitive_file.docker_env.filename
}
