{
  lib,
  pkgs,
  osConfig,
  config,
  inputs,
  ...
}:
let
  cfg = config.bars.ricelin;
  c = osConfig.host.themeData.base16Scheme;

  # Bridge Ricelin's hand-picked warm-vermilion palette onto the system theme
  # (host.themeData / base16). Backgrounds and foregrounds map straight onto
  # base00..base07; the accent "flame" ramp is a curated warm set anchored on
  # base08 (kanagawa-dragon red) since pure-Nix has no colour math to derive
  # the lighter/darker shades. Tune these literals for taste.
  themeReplace = {
    # accent / flame ramp
    "#c0442b" = "#${c.base08}"; # verm
    "#e0563b" = "#e46876"; # vermLit (dragon bright red)
    "#a3371f" = "#a85a54"; # vermDeep
    "#8a5440" = "#8a6a64"; # vermDim
    "#5a3526" = "#5a4240"; # vermDimDeep
    "#8a2c14" = "#7d4a44"; # vermBurn
    "#7e2812" = "#6e3a36"; # flameEmber
    "#f0795a" = "#d4837e"; # flameInk
    "#ffb38a" = "#e0a89a"; # flameTip / todayWarm
    "#ff9a64" = "#d99a86"; # flameGlow
    "#ffd9c2" = "#ecd9d0"; # flameCore
    # foregrounds
    "#fff6f0" = "#e6e0cf"; # bright
    "#fbeee7" = "#e3ddcc";
    "#f1e4db" = "#${c.base07}";
    "#e6d6cb" = "#${c.base07}"; # cream
    "#cdbfb4" = "#${c.base05}"; # iconDim
    "#cbb6a3" = "#b6bab6"; # tickRest
    "#b9a99e" = "#${c.base04}"; # subtle
    "#8a7d74" = "#7a756e"; # dim
    "#6f635b" = "#${c.base03}"; # faint
    "#594636" = "#4a4640"; # ghost
    "#5a5048" = "#4d4944";
    # backgrounds (warm darks -> base00..base02)
    "#2e231b" = "#${c.base02}"; # cardTop
    "#221813" = "#${c.base00}"; # cardBot
    "#211711" = "#${c.base01}"; # tileBg
    "#3a2a22" = "#2e2c2b"; # border
    "#3a291f" = "#2e2c2b";
    "#2c1f19" = "#${c.base01}";
    "#2c2118" = "#${c.base01}";
    "#251a12" = "#1a1818";
    "#1a110c" = "#141313";
  };
  replaceArgs = lib.concatStringsSep " " (
    lib.mapAttrsToList (from: to: "--replace-quiet '${from}' '${to}'") themeReplace
  );

  # Wallpaper directory the pill's wallpaper picker reads from. Ricelin
  # hardcodes ~/Ricelin/wallpapers; we point it at the Kanagawa set used by
  # the rest of the system.
  wallpaperDir = toString inputs.wallpapers;

  # Runtime scripts (daemons, IPC wrappers, clipboard/wallpaper helpers).
  # Delivered as one directory so the thumbnail scripts' relative
  # `$(dirname "$0")/magick-policy` lookup keeps working.
  scriptsDir = pkgs.runCommand "ricelin-scripts" { } ''
    mkdir -p $out
    cp -r ${./ricelin/scripts}/. $out/
    chmod -R u+w $out
    for f in $out/wallpaper.sh $out/wallpaper-thumbs.sh; do
      substituteInPlace "$f" --replace '$HOME/Ricelin/wallpapers' '${wallpaperDir}'
    done
    chmod +x $out/*.sh
  '';

  # The Quickshell config trees, delivered read-only from the store. Ricelin
  # writes all runtime state to $XDG_STATE_HOME/ricelin and $XDG_CACHE_HOME,
  # never into the config dir, so a read-only symlink is safe.
  #
  # Shells with a Theme.qml singleton get a themed copy (Theme.qml recoloured
  # from the system palette); the rest are delivered verbatim.
  themedShells = [
    "pill"
    "topbar"
    "sidebar"
    "lock"
  ];
  plainShells = [
    "launcher"
    "rishot"
  ];

  themedShell =
    name:
    pkgs.runCommand "ricelin-${name}" { } ''
      mkdir -p $out
      cp -r ${./ricelin/quickshell + "/${name}"}/. $out/
      chmod -R u+w $out
      substituteInPlace $out/Singletons/Theme.qml ${replaceArgs}
    '';

  shellSource =
    name: if lib.elem name themedShells then themedShell name else ./ricelin/quickshell + "/${name}";
  allShells = themedShells ++ plainShells;
in
{
  options = {
    bars.ricelin.enable = lib.mkEnableOption "Enable Ricelin (hand-written Quickshell) shell";
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      (with pkgs; [
        quickshell
        jq
        cliphist
        wl-clipboard
        cava
        imagemagick
        grim
        slurp
        hyprpolkitagent
        libnotify
        bibata-cursors
        inter
      ])
      # NVIDIA digital-vibrance helper used by the pill/sidebar display tiles.
      ++ lib.optional (osConfig.host.gpuType == "nvidia") pkgs.nvibrant;

    # Quickshell config trees -> ~/.config/quickshell/<name>, plus runtime
    # scripts -> ~/.config/hypr/scripts (Ricelin's expected layout).
    xdg.configFile =
      lib.listToAttrs (
        map (n: {
          name = "quickshell/${n}";
          value = {
            source = shellSource n;
            recursive = true;
          };
        }) allShells
      )
      // {
        "hypr/scripts" = {
          source = scriptsDir;
          recursive = true;
        };
      };
  };
}
