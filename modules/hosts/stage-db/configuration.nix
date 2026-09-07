_: {
  flake.nixosModules.stageDb =
    { inputs, lib, ... }:
    {
      imports = [
        "${inputs.self}/modules/hosts/_oci-common.nix"
        inputs.self.nixosModules.forgejo
      ];

      networking.hostName = "stage-db";

      services.infra.forgejo.enable = true;
      # This OCI boot disk is 46 GiB; desktop thresholds would continuously GC.
      nix.settings.min-free = lib.mkForce (1024 * 1024 * 1024);
      nix.settings.max-free = lib.mkForce (2 * 1024 * 1024 * 1024);
    };
}
