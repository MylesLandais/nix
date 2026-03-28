{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
{
  environment.systemPackages = [
    pkgs.ghostty
    inputs.zen-browser.packages.x86_64-linux.default
    inputs.agenix.packages.x86_64-linux.default
    inputs.opencode.packages.x86_64-linux.default
    inputs.wallpapers.packages.x86_64-linux.default
    inputs.helium.defaultPackage.x86_64-linux
  ]
  ++ lib.optional (
    config.host.bar == "caelestia"
  ) inputs.caelestia-shell.packages.x86_64-linux.default
  ++ lib.optional (config.host.bar == "noctalia") inputs.noctalia.packages.x86_64-linux.default;
}
