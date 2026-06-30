{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
let
  heliumUpstream = inputs.helium.defaultPackage.x86_64-linux;
  # Upstream `helium` hardcodes --enable-features=VaapiVideoDecoder and ignores
  # ~/.config/helium-flags.conf. Call .helium-wrapped directly and inject HM flags.
  heliumWithFlags = pkgs.writeShellScriptBin "helium" ''
    set -eu
    helium="${heliumUpstream}/bin/.helium-wrapped"
    flagsFile="''${XDG_CONFIG_HOME:-$HOME/.config}/helium-flags.conf"
    extra=()
    if [ -r "$flagsFile" ]; then
      while IFS= read -r line; do
        extra+=("$line")
      done < <(grep -Ev '^(#|$)' "$flagsFile")
    fi
    if ((''${#extra[@]})); then
      exec -a helium "$helium" "''${extra[@]}" "$@"
    else
      exec -a helium "$helium" --enable-features=VaapiVideoDecoder "$@"
    fi
  '';
in
{
  environment.systemPackages = [
    pkgs.ghostty
    inputs.zen-browser.packages.x86_64-linux.default
    inputs.agenix.packages.x86_64-linux.default
    inputs.trigo.packages.x86_64-linux.default
    inputs.llm.packages.x86_64-linux.opencode
    inputs.wallpapers.packages.x86_64-linux.default
    heliumWithFlags
    inputs.antigravity-nix.packages.x86_64-linux.google-antigravity-ide
    inputs.antigravity-nix.packages.x86_64-linux.google-antigravity-cli
  ]
  ++ lib.optional (config.host.bar == "noctalia") inputs.noctalia.packages.x86_64-linux.default;
}
