# Code Server Connection Guide

## Quick Start

After rebuilding NixOS with the new configuration:

```bash
sudo nixos-rebuild switch
```

## Accessing Code Server

1. **URL**: `http://<your-server-ip>:8080`
2. **Password**: `devsandbox123`

## Your Workspace

Your `~/Workspace` directory is mounted at `/home/coder/Workspace` inside the container.

## Troubleshooting Commands

### Check if container is running:
```bash
sudo podman ps
```

### Check container logs:
```bash
sudo podman logs code-server
```

### Start container manually if needed:
```bash
sudo podman start code-server
```

### Stop container:
```bash
sudo podman stop code-server
```

## Configuration Options

You can customize the code-server by modifying the options in `modules/dev.nix`:

- **Port**: Change `config.dev.containers.codeServer.port` (default: 8080)
- **Password**: Change `config.dev.containers.codeServer.password` (default: "devsandbox123")
- **Image**: Change `config.dev.containers.codeServer.image` (default: "linuxserver/code-server:latest")

After making changes, rebuild with:
```bash
sudo nixos-rebuild switch