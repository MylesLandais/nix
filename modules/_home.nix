{
  pkgs,
  lib,
  config,
  osConfig,
  inputs,
  ...
}:
let
  gpuType = osConfig.host.gpuType or "none";

  chromiumBrowsers = import ./_chromium-browsers.nix { inherit lib; };
  inherit (chromiumBrowsers)
    mkChromiumFlags
    chromiumStandardBrowserFlags
    ;

  vaapiMode =
    if gpuType == "nvidia" then
      "nvidia"
    else if gpuType == "amd" then
      "generic"
    else
      false;

  chromiumFlagsFile = mkChromiumFlags (chromiumStandardBrowserFlags // { inherit vaapiMode; });

  # Helium and Vivaldi both still show blocky WebM/GIF artifacts on nvidia
  # even with UseChromeOSDirectVideoDecoder disabled; fall back to software
  # decode (fallback ladder rung 3 in chromium-browsers.nix) for both.
  # Chromium proper has not shown the issue, so it keeps hardware decode.
  softwareDecodeFlagsFile = mkChromiumFlags (chromiumStandardBrowserFlags // { vaapiMode = false; });

  # Codex ships an official portable package containing codex, codex-code-mode-host
  # and their resources in one tree. Use it instead of overriding the llm flake's
  # derivation: an override produces a store path nobody has published, so it fell
  # back to a full Rust build — ~40 minutes on every `llm` bump.
  #
  # A symlinkJoin of the cached codex plus a standalone helper does NOT work.
  # codex-rs/install-context/src/lib.rs canonicalizes std::env::current_exe() and
  # resolves the helper as a sibling of the real binary; on Linux current_exe()
  # reads /proc/self/exe, which follows symlinks straight back to the original store
  # path, where the helper is absent. The whole package has to move together.
  codexVersion = "0.147.0";
  llmCodex = inputs.llm.packages.${pkgs.system}.codex;
  llmCodexVersion = llmCodex.version or (lib.getVersion llmCodex.name);

  # Fail loudly if the `llm` input moves codex without this release tag following it,
  # rather than silently pairing a helper binary with a different codex.
  patchedCodex =
    assert lib.assertMsg (llmCodexVersion == codexVersion)
      "codex release ${codexVersion} is out of sync with llm codex ${llmCodexVersion} — bump codexVersion and its hash in modules/_home.nix";
    pkgs.stdenv.mkDerivation {
      pname = "codex";
      version = codexVersion;

    src = pkgs.fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/codex-package-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-vXWNU9VuQdxl4EX0WJ33mgOO0ZegEa3LUqJY5q1kz9o=";
    };

    # codex, codex-code-mode-host, rg and bwrap are static-pie and need nothing.
    # codex-resources/zsh/bin/zsh is the one dynamically linked binary in the
    # archive (interpreter /lib64/ld-linux-x86-64.so.2, needs libtinfo.so.6) and
    # cannot exec on NixOS unpatched. Codex reaches it via bundled_zsh_path().
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [
      pkgs.ncurses
      pkgs.stdenv.cc.cc.lib
    ];

    dontUnpack = true;
    dontStrip = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$TMPDIR/unpack" "$out"
      tar -xzf "$src" -C "$TMPDIR/unpack"

      packageRoot="$(find "$TMPDIR/unpack" -type f -name codex-package.json -printf '%h\n' -quit)"
      if [ -z "$packageRoot" ]; then
        echo "codex-package.json not found in release archive" >&2
        exit 1
      fi

      cp -a "$packageRoot"/. "$out"/

      test -f "$out/codex-package.json"
      test -x "$out/bin/codex"
      test -x "$out/bin/codex-code-mode-host"

      runHook postInstall
    '';

    meta = {
      mainProgram = "codex";
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };
in
{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.

  imports = [
    ./_features/app-wrappers.nix
    ./_features/chromium-helium-prefs.nix
    ./_features/desktops/hyprland
    ./_features/desktops/niri
    ./_features/desktops/xfce
    ./_features/bars
    ./_features/prompt
    ./_features/shelltools
    ./_features/devtooling
    ./_features/gtk
    ./_features/terminals
    ./_features/mpv
    ./_features/stylix
    ./_features/flameshot.nix
    ./_features/ssh-bitwarden.nix
    ./_firefox.nix
    inputs.stylix.homeModules.stylix
    inputs.noctalia.homeModules.default
    inputs.tokyonight.homeManagerModules.default
  ];
  fonts.fontconfig.enable = true;

  home = {
    enableNixpkgsReleaseCheck = false;
    stateVersion = "24.11"; # Please read the comment before changing.
    sessionVariables = {
      OZONE_PLATFORM = "wayland";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
      EDITOR = "nvim";
      SSH_AUTH_SOCK = "${config.home.homeDirectory}/.bitwarden-ssh-agent.sock";
    };

    file = {
      "${config.xdg.configHome}/helium-flags.conf".text = softwareDecodeFlagsFile;
      "${config.xdg.configHome}/chromium-flags.conf".text = chromiumFlagsFile;
      "${config.xdg.configHome}/vivaldi-flags.conf".text = softwareDecodeFlagsFile;
    };

    packages = (import ./_packages.nix { inherit pkgs; }) ++ [ patchedCodex ];
    pointerCursor = {
      gtk.enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 22;
    };
  };

  # Custom modules
  prompt.enable = true;
  devtooling.enable = true;
  shelltools.enable = true;
  stylix-mod.enable = true;
  gtk-mod.enable = true;
  hyprland.enable = true;
  terminals.enable = true;
  mpv-mod.enable = true;
  appWrappers.enable = lib.mkDefault true;
  chromiumHeliumPrefs.enable = lib.mkDefault true;

  programs.firefox.preferences = lib.mkIf (gpuType == "nvidia") {
    "media.ffmpeg.vaapi.enabled" = true;
    "media.hardware-video-decoding.force-enabled" = true;
  };

  # Gammastep: auto-adjust screen color temperature for eye fatigue reduction.
  # Uses wayland backend for Hyprland. Coordinates default to Chicago (cerberus).
  # Override per-host via hosts/<name>/home.nix if needed.
  services.gammastep = {
    enable = true;
    provider = "manual";
    latitude = 41.9;
    longitude = -87.6;
    temperature = {
      day = 6500;
      night = 3500;
    };
    settings = {
      general = {
        adjustment-method = "wayland";
        brightness-day = 1.0;
        brightness-night = 0.9;
      };
    };
  };

  # Minimal programs configuration
  programs = {
    home-manager.enable = true;
    firefox.enable = true;
    # Extensions and policies for Helium / Chromium come from chromiumPolicies
    # on Cerberus (see hosts/cerberus/configuration.nix).
    chromium.enable = true;
    btop = {
      enable = true;
      settings = {
        theme_background = false;
      };
    };
    git = {
      delta.tokyonight.enable = false;
      lfs.enable = true;
    };
    onlyoffice.enable = true;
    wofi.enable = false;

    fuzzel = {
      enable = true;
      settings = {
        main = {
          font = "Hack Nerd Font";
          prompt = ''">    "'';
          lines = 20;
          width = 60;
          horizontal-pad = 40;
          vertical-pad = 16;
          inner-pad = 6;
        };
        colors = {
          background = "1e1e2efa";
          text = "19617813801";
          border = "#c4b28a";
        };
      };
    };
  };

}
