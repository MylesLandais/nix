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

  # nixpkgs' `vivaldi` is a compiled makeBinaryWrapper stub with no baked-in
  # args and no support for reading ~/.config/vivaldi-flags.conf -- unlike
  # helium's launcher, it silently ignores that file entirely. Wrap the real
  # binary ourselves and symlinkJoin it with the upstream package so we keep
  # its desktop entry/icons/policy layout while our bin/vivaldi (listed
  # first) wins the collision.
  vivaldiWithFlags = pkgs.symlinkJoin {
    name = "vivaldi";
    paths = [
      (pkgs.writeShellScriptBin "vivaldi" ''
        set -eu
        vivaldi="${pkgs.vivaldi}/bin/.vivaldi-wrapped"
        flagsFile="''${XDG_CONFIG_HOME:-$HOME/.config}/vivaldi-flags.conf"
        extra=()
        if [ -r "$flagsFile" ]; then
          while IFS= read -r line; do
            extra+=("$line")
          done < <(grep -Ev '^(#|$)' "$flagsFile")
        fi
        exec -a vivaldi "$vivaldi" "''${extra[@]}" "$@"
      '')
      pkgs.vivaldi
    ];
  };
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
    vivaldiWithFlags
    inputs.antigravity-nix.packages.x86_64-linux.google-antigravity-ide
    inputs.antigravity-nix.packages.x86_64-linux.google-antigravity-cli
    # System utilities
    pkgs.git
    pkgs.cifs-utils
    pkgs.wireguard-tools
    pkgs.nmap
    pkgs.ntfs3g
    pkgs.bubblewrap # codex warns on every launch without a bwrap on PATH
    pkgs.polkit_gnome # GTK polkit auth agent for keyring unlock prompts
    pkgs.libsecret # secret-tool CLI for keyring debugging
    pkgs.libgnome-keyring # legacy compat for older apps (VS Code etc.)
    # Desktop theming
    pkgs.papirus-icon-theme
    pkgs.kdePackages.breeze-icons
    pkgs.adwaita-icon-theme
    # Applications
    pkgs.bitwarden-desktop
    pkgs.bitwarden-cli
    pkgs.dolphin-emu
    pkgs.teamspeak6-client
    pkgs.termius
    pkgs.mosh
    pkgs.nicotine-plus
    pkgs.foliate # epub reader; Evince/Document Viewer has no epub support
    inputs.hermes-agent.packages.${pkgs.system}.desktop # Hermes GUI (Electron), wraps the hermes CLI agent
    pkgs.buzz-desktop # Buzz GUI (Tauri) plus its buzz/buzz-acp/buzz-agent/buzz-dev-mcp CLIs
    pkgs.kimi-code # Kimi Code 0.34.0 (bin/kimi and bin/kimi-code)
  ]
  ++ lib.optional (config.host.bar == "noctalia") inputs.noctalia.packages.x86_64-linux.default;
}
