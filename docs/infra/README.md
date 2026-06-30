# Infra demo (cerberus)

Cerberus-local SSO + OpenBao service accounts for Maya.

## Stack

- **Authentik** — human SSO (`warby` user)
- **Traefik** — ForwardAuth ingress (HTTP demo mode on port 80)
- **OpenBao** — `maya-agent` AppRole for Discord + pyLoad creds
- **Postgres / Valkey** — Authentik backends

## Enable

In [`modules/hosts/cerberus/configuration.nix`](../modules/hosts/cerberus/configuration.nix):

```nix
infra.demo.enable = true;
```

## DNS

```
127.0.0.1 auth.homelab.lan downloads.homelab.lan
```

## Before rebuild

```bash
docker stop dev.traefik 2>/dev/null || true
```

## Rebuild

```bash
nix build .#nixosConfigurations.cerberus.config.system.build.toplevel
sudo nixos-rebuild switch --flake .#cerberus
```

## Authentik first boot

1. http://auth.homelab.lan/if/flow/initial-setup/
2. Create user `warby`
3. Application → Proxy provider → `http://downloads.homelab.lan`
4. Deploy Traefik outpost; update token in authentik-outpost service

## Smoke tests

See [`secrets/README.md`](../secrets/README.md) for OpenBao bootstrap.

```bash
curl -I http://downloads.homelab.lan
systemctl status maya-bot openbao authentik-server pyload
```
