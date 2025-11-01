# Simplified Code Server Setup

## Overview
This document provides a simplified configuration for running code-server with Podman, focusing on just mounting the user's `~/Workspace` directory with minimal complexity.

## Issues with Current Setup
1. Complex volume mounts with multiple directories
2. SSL certificate management adding unnecessary complexity
3. Additional containers (Portainer, Chrome Remote) not needed for basic code-server
4. Complex directory creation and ownership requirements

## Simplified Configuration

### Replace the existing `modules/dev.nix` with this simplified version:

```nix
{
  config,
  lib,
  pkgs,
  ...
}:

{

  options.dev = {
    enable = lib.mkEnableOption "Enable developer tooling module" // {
      default = true;
    };

    containers = {
      codeServer = {
        image = lib.mkOption {
          type = lib.types.str;
          default = "linuxserver/code-server:latest";
          description = "Docker image for code-server container";
        };
        port = lib.mkOption {
          type = lib.types.int;
          default = 8080;
          description = "Port for code-server";
        };
        password = lib.mkOption {
          type = lib.types.str;
          default = "devsandbox123";
          description = "Password for code-server";
        };
      };
    };
  };

  config = lib.mkIf config.dev.enable {
    # Enable Podman for container management
    virtualisation = {
      podman = {
        enable = true;
        dockerCompat = true;
        dockerSocket.enable = true;
      };
      
      oci-containers = {
        backend = "podman";
        containers = {
          "code-server" = {
            image = config.dev.containers.codeServer.image;
            ports = [ "${toString config.dev.containers.codeServer.port}:8080" ];
            volumes = [
              "/home/warby/Workspace:/home/coder/Workspace"
            ];
            environment = {
              PASSWORD = config.dev.containers.codeServer.password;
              TZ = "America/New_York";
              PUID = "1000";
              PGID = "1000";
              DEFAULT_WORKSPACE = "/home/coder/Workspace";
            };
            cmd = [
              "--bind-addr"
              "0.0.0.0:8080"
              "--disable-telemetry"
              "--disable-update-check"
            ];
            autoStart = true;
          };
        };
      };
    };

    # Open firewall for code-server port
    networking.firewall.allowedTCPPorts = [ config.dev.containers.codeServer.port ];

    # Add useful packages
    environment.systemPackages = with pkgs; [
      podman-compose
      lazydocker
    ];

    # Add user to podman group
    users.groups.podman.members = [ "warby" ];
  };
}
```

## Key Simplifications

1. **Removed SSL/TLS**: Using HTTP instead of HTTPS for simplicity
2. **Minimal Volume Mounts**: Only mounting the essential `~/Workspace` directory
3. **Removed Additional Containers**: Focusing only on code-server
4. **Simplified Directory Structure**: Letting code-server manage its own configuration
5. **Configurable Options**: Made port and password configurable through Nix options

## Connection Instructions

1. After applying the configuration and rebuilding NixOS:
   ```bash
   sudo nixos-rebuild switch
   ```

2. Access code-server at: `http://<your-server-ip>:8080`

3. Login with password: `devsandbox123` (or whatever you configured)

4. Your workspace will be available at `/home/coder/Workspace` inside the container

## Troubleshooting

### If the container doesn't start:
1. Check container status:
   ```bash
   sudo podman ps -a
   ```

2. Check container logs:
   ```bash
   sudo podman logs code-server
   ```

3. Manually start the container if needed:
   ```bash
   sudo podman start code-server
   ```

### If you can't access the web interface:
1. Verify the port is open:
   ```bash
   sudo ss -tlnp | grep 8080
   ```

2. Check firewall rules:
   ```bash
   sudo nixos-rebuild switch
   ```

### If workspace files aren't visible:
1. Verify the workspace directory exists:
   ```bash
   ls -la ~/Workspace
   ```

2. Check permissions:
   ```bash
   sudo podman exec -it code-server ls -la /home/coder/Workspace
   ```

## Optional Enhancements

Once the basic setup is working, you can consider adding:

1. **SSL/TLS**: Add certificate management for secure connections
2. **Additional Extensions**: Pre-install VS Code extensions
3. **Custom Settings**: Configure default VS Code settings
4. **Auto-start Services**: Add other development tools as needed

## Migration from Current Setup

To migrate from the current setup:

1. Backup your current `modules/dev.nix`:
   ```bash
   cp modules/dev.nix modules/dev.nix.backup
   ```

2. Replace with the simplified configuration above

3. Rebuild NixOS:
   ```bash
   sudo nixos-rebuild switch
   ```

4. Test the new setup by accessing code-server

5. If everything works, you can remove the backup file