_: {
  flake.modules.nixos.stageEdge =
    { inputs, ... }:
    {
      imports = [
        "${inputs.self}/modules/hosts/_oci-common.nix"
      ];

      networking.hostName = "stage-edge";

      # -------------------------------------------------------------------------
      # Administration
      # -------------------------------------------------------------------------
      # Password authentication is disabled in _oci-common.nix. These accounts
      # stay inaccessible until their individual SSH public keys are added.
      users.users = {
        lain = {
          isNormalUser = true;
          description = "Lain";
          hashedPassword = "!";
          extraGroups = [ "wheel" ];
          openssh.authorizedKeys.keys = [ ];
        };

        fran = {
          isNormalUser = true;
          description = "Fran";
          hashedPassword = "!";
          extraGroups = [ "wheel" ];
          openssh.authorizedKeys.keys = [ ];
        };
      };
    };
}
