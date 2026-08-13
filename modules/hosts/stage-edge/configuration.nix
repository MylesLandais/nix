_: {
  flake.nixosModules.stageEdge =
    { inputs, ... }:
    {
      imports = [ "${inputs.self}/modules/hosts/_oci-common.nix" ];

      networking.hostName = "stage-edge";

      # -------------------------------------------------------------------------
      # Placeholder service
      # -------------------------------------------------------------------------
      # Deliberately plain nginx rather than the repo's traefikInfra module:
      # traefik drives ACME over an HTTP-01 challenge, which cannot complete on a
      # host with no public ingress. This exists only to prove the chain
      # NixOS -> tailnet -> reverse proxy -> second device. Swap in Traefik and
      # the real project once that path is verified, using DNS-01 or Tailscale
      # certs for TLS.
      services.nginx = {
        enable = true;
        virtualHosts."stage-edge" = {
          default = true;
          locations."/".return = "200 'stage-edge placeholder OK\\n'";
          extraConfig = ''
            default_type text/plain;
          '';
        };
      };

      # Reachable over the tailnet only — never on the VCN interface. This
      # per-interface firewall idiom is the repo's existing tailnet trust
      # boundary (see modules/security/openbao.nix, modules/database/valkey.nix).
      networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 80 ];
    };
}
