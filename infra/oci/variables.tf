# ==============================================================================
# OCI Authentication & Placement Variables
# ==============================================================================
variable "tenancy_ocid" {
  type        = string
  description = "OCID of the Oracle Cloud tenancy"
  default     = "ocid1.tenancy.oc1..aaaaaaaafoq2dz3ms7ornngy5sa663irqr2feekoc222643yu6m5zaoqrbua"
}

variable "compartment_ocid" {
  type        = string
  description = "OCID of the compartment where resources will reside"
  default     = "ocid1.tenancy.oc1..aaaaaaaafoq2dz3ms7ornngy5sa663irqr2feekoc222643yu6m5zaoqrbua"
}

variable "region" {
  type        = string
  description = "OCI Region identifier (e.g. us-chicago-1)"
  default     = "us-chicago-1"
}

variable "user_ocid" {
  type        = string
  description = "OCID of the OCI user executing OpenTofu (leave empty if using InstancePrincipal or Token)"
  default     = ""
}

variable "fingerprint" {
  type        = string
  description = "Fingerprint of the user API key (leave empty if using InstancePrincipal or Token)"
  default     = ""
}

variable "private_key_path" {
  type        = string
  description = "Path to the OCI API private key file (PEM format)"
  default     = ""
}

variable "auth" {
  type        = string
  description = "Authentication type for OCI provider (ApiKey, InstancePrincipal, SecurityToken)"
  default     = "ApiKey"
}

# ==============================================================================
# Network & Target Variables
# ==============================================================================
variable "public_subnet_ocid" {
  type        = string
  description = "OCID of the public subnet where the Network Load Balancer will receive public traffic"
  default     = "ocid1.subnet.oc1.us-chicago-1.aaaaaaaapm7gon4sm2nkda6rmww7yiy2g4t7nevvtf3dixnzmlukhw3tlnua"
}

variable "vcn_ocid" {
  type        = string
  description = "OCID of the VCN (required if manage_security_list is true)"
  default     = "ocid1.vcn.oc1.us-chicago-1.amaaaaaapizkb5iaewmfo4konfy72plp6f636clpwob5w5wqwx2eedvq2j3q"
}

variable "vcn_cidr" {
  type        = string
  description = "CIDR block of the VCN"
  default     = "10.0.0.0/16"
}

variable "manage_security_list" {
  type        = bool
  description = "Whether to provision an OCI Security List allowing port 22 public ingress and port 2222 internal VCN ingress"
  default     = false
}

variable "stage_db_private_ip" {
  type        = string
  description = "Private IP address of the stage-db Forgejo host"
  default     = "10.0.6.242"
}

variable "reserved_ip_id" {
  type        = string
  description = "Optional OCID of an existing reserved public IPv4 address to attach to the NLB"
  default     = ""
}

# ==============================================================================
# Cloudflare DNS Integration Variables
# ==============================================================================
variable "manage_cloudflare_dns" {
  type        = bool
  description = "Whether to automatically create the ssh.nebula-1.com DNS record in Cloudflare"
  default     = true
}

variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token scoped to Zone.DNS edit"
  sensitive   = true
  default     = ""
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare Zone ID for nebula-1.com"
  default     = ""
}

variable "ssh_domain" {
  type        = string
  description = "Subdomain to assign for public Git SSH access"
  default     = "ssh.nebula-1.com"
}
