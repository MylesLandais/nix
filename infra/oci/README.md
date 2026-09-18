# OCI Network Load Balancer for Forgejo Git SSH

This OpenTofu module provisions an **Always Free Network Load Balancer (NLB)** in Oracle Cloud Infrastructure (OCI) and sets up public DNS routing for Git SSH access to Forgejo on `stage-db`.

## Architecture

- **Public Listener (TCP:22)**: Receives standard Git SSH requests on the default SSH port 22 from contributors over the public internet.
- **Backend Set (TCP:2222)**: Forwards traffic directly to `stage-db` at `10.0.6.242:2222` (where the rootless Forgejo SSH daemon listens).
- **Source IP Preservation Disabled**: Crucial for backends in a private subnet using a NAT Gateway as default route; disabling source preservation ensures replies route back through the NLB instead of exiting the NAT Gateway (which would break the TCP handshake).
- **Cloudflare DNS (`ssh.nebula-1.com`)**: Unproxied (grey-cloud) A-record pointing directly to the NLB's public IP address.

## Prerequisites

1. An OCI user or session with permissions to create and manage Network Load Balancers in your compartment.
2. The OCID of your VCN's **Public Subnet**.
3. Security List / NSG ingress rules:
   - **Public Subnet**: Allow TCP port 22 ingress from `0.0.0.0/0`.
   - **Private Subnet**: Allow TCP port 2222 ingress from the VCN CIDR (`10.0.0.0/16`).

## Usage

Create `infra/oci/.env.oci` (ignored by git):

```sh
export TF_VAR_tenancy_ocid="ocid1.tenancy.oc1..aaaaaaaafoq2dz3ms7ornngy5sa663irqr2feekoc222643yu6m5zaoqrbua"
export TF_VAR_compartment_ocid="ocid1.tenancy.oc1..aaaaaaaafoq2dz3ms7ornngy5sa663irqr2feekoc222643yu6m5zaoqrbua"
export TF_VAR_user_ocid="ocid1.user.oc1..aaaaaaaa6eiax5eqvgqvo57qn7xeviuixbkplt2dq37gnjeoyu5gnptrhmrq"
export TF_VAR_fingerprint="<your_api_key_fingerprint>"
export TF_VAR_private_key_path="~/.oci/oci_api_key.pem"
export TF_VAR_public_subnet_ocid="<ocid_of_public_subnet>"
export TF_VAR_cloudflare_api_token="<your_cloudflare_api_token>"
export TF_VAR_cloudflare_zone_id="<your_cloudflare_zone_id>"
```

Then initialize and apply:

```sh
set -a
source infra/oci/.env.oci
set +a

tofu -chdir=infra/oci init
tofu -chdir=infra/oci plan -out=tfplan
tofu -chdir=infra/oci apply tfplan
```

Once applied, the NLB public IP is created, `ssh.nebula-1.com` is pointed to it, and contributors can clone/push using:

```sh
git clone git@ssh.nebula-1.com:<user>/<repo>.git
```
