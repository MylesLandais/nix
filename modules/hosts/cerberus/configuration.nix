_: {
  # Lift-and-shift wrapper: imports the pre-port cerberus config verbatim from
  # legacy/. Translation into the dendritic feature-module layout happens
  # incrementally per PORT.md.
  flake.nixosModules.cerberus =
    { ... }:
    {
      imports = [
        ../../../legacy/cerberus/configuration.nix
        ../../../legacy/modules/gnome-keyring.nix
      ];
    };
}
