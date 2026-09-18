variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}
variable "cloudflare_account_id" { type = string }
variable "cloudflare_zone_id" { type = string }
variable "domain" {
  type    = string
  default = "git.nebula-1.com"
}
variable "ssh_domain" {
  type    = string
  default = "ssh.nebula-1.com"
}
variable "ssh_port" {
  type    = string
  default = "22"
}
variable "ssh_nlb_ip" {
  type        = string
  default     = ""
  description = "Public IPv4 address of the OCI Network Load Balancer for Git SSH"
}
