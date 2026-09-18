output "nlb_id" {
  description = "OCID of the Network Load Balancer"
  value       = oci_network_load_balancer_network_load_balancer.forgejo_ssh.id
}

output "nlb_public_ip" {
  description = "Public IPv4 address assigned to the Network Load Balancer"
  value       = local.nlb_ip
}

output "ssh_endpoint" {
  description = "Configured public SSH endpoint for Git operations"
  value       = var.manage_cloudflare_dns ? var.ssh_domain : local.nlb_ip
}

output "clone_url_example" {
  description = "Example Git SSH clone URL for contributors"
  value       = "git@${var.manage_cloudflare_dns ? var.ssh_domain : local.nlb_ip}:<organization>/<repository>.git"
}
