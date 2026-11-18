_: {
  flake.modules.nixos.fishConfig = _: {
    programs.fish = {
      enable = true;
      useBabelfish = true;
    };
  };
}
