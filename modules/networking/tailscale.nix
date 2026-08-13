# Tailscale node with unattended enrolment.
#
# The repo previously enabled `services.tailscale.enable` per host and ran
# `tailscale up` by hand (see docs/cluster/95qmom2.md, which flags the manual
# flow as a gap). The OCI hosts have no public IP and are reachable only through
# a Bastion port-forwarding session, so they must join the tailnet on their own
# during first boot — hence authKeyFile.
#
# The key is deliberately NOT an agenix secret: agenix decrypts with
# /etc/ssh/ssh_host_ed25519_key (modules/_agenix.nix), which does not exist until
# after the install completes. The bootstrap key is placed out-of-band by
# nixos-anywhere --extra-files. Move to agenix once these hosts hold real
# credentials and their host keys are recipients in secrets/secrets.nix.
_: {
  flake.nixosModules.tailscaleNode =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.infra.tailscale;
    in
    {
      options.services.infra.tailscale = {
        enable = lib.mkEnableOption "Tailscale node with unattended enrolment";

        authKeyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          example = "/etc/tailscale/authkey";
          description = ''
            Path to a file containing a Tailscale auth key, read at activation.
            Must exist outside the Nix store (the store is world-readable).
            When null the node is enabled but enrolment stays manual.
          '';
        };

        extraUpFlags = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "--advertise-tags=tag:oci-stage" ];
          description = "Extra flags passed to `tailscale up`.";
        };

        routingFeatures = lib.mkOption {
          type = lib.types.enum [
            "none"
            "client"
            "server"
            "both"
          ];
          default = "client";
          description = ''
            Passed through to services.tailscale.useRoutingFeatures. Use "server"
            for subnet routers or exit nodes, which also relaxes reverse-path
            filtering.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        services.tailscale = {
          enable = true;
          inherit (cfg) authKeyFile;
          inherit (cfg) extraUpFlags;
          useRoutingFeatures = cfg.routingFeatures;
        };

        environment.systemPackages = [ pkgs.tailscale ];

        # Subnet routing / exit-node traffic arrives on tailscale0 with a source
        # address the strict rp_filter rejects.
        networking.firewall.checkReversePath = lib.mkIf (builtins.elem cfg.routingFeatures [
          "server"
          "both"
        ]) "loose";

        # Without this the unit can start before the NAT gateway route is usable
        # and burn its (rate-limited) enrolment attempt. `wants` as well as
        # `after` — ordering alone does not pull the target in, which NixOS warns
        # about at eval time.
        systemd.services.tailscaled-autoconnect = lib.mkIf (cfg.authKeyFile != null) {
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
        };
      };
    };
}
