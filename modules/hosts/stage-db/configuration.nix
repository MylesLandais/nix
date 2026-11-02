_: {
  flake.modules.nixos.stageDb =
    { inputs, ... }:
    {
      imports = [
        "${inputs.self}/modules/hosts/_oci-common.nix"
        inputs.self.modules.nixos.forgejo
      ];

      networking.hostName = "stage-db";

      # Jovan's key registered to the Forgejo account lain; stage-db only.
      users.users.root.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFmp56XSe1dnasZtnUW3xp7ywYPA3nnN10W77/+ZXAo1 jovan@VE-18022026657"
      ];

      services.infra.forgejo.enable = true;
    };
}
