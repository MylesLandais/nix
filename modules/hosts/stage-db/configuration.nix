_: {
  flake.nixosModules.stageDb =
    { inputs, ... }:
    {
      imports = [ "${inputs.self}/modules/hosts/_oci-common.nix" ];

      networking.hostName = "stage-db";

      # No database yet — Postgres/SeaweedFS land here once the tailnet path is
      # proven. Until then this host exists to validate that the install recipe
      # reproduces on a second machine.
    };
}
