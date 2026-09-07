_: {
  flake.nixosModules.stageDb =
    { inputs, ... }:
    {
      imports = [ "${inputs.self}/modules/hosts/_oci-common.nix" inputs.self.nixosModules.forgejo ];

      networking.hostName = "stage-db";

      services.infra.forgejo.enable = true;
    };
}
