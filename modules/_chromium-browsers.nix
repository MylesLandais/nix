# Shared Chromium / Helium extension IDs and launch flags.
# Imported by chromium-policy.nix (NixOS) and modules/home.nix (Home Manager).
{ lib }:
let
  # Force-installed extension pack for all Chromium-based browsers on Cerberus.
  chromiumExtensionPack = {
    uBlockOriginLite = {
      id = "ddkjiahejlhfcafbddmgiahcphecmpfh";
      name = "uBlock Origin Lite";
    };
    bitwarden = {
      id = "nngceckbapebfimnlniiiahkandclblb";
      name = "Bitwarden";
    };
    darkReader = {
      id = "eimadpbcbfnmbkopoojfekhnkhdbieeh";
      name = "Dark Reader";
    };
    chatgpt = {
      id = "hehggadaopoacecdllhhajmbjkdcmajg";
      name = "ChatGPT";
    };
  };

  chromiumStandardExtensions = map (e: e.id) (lib.attrValues chromiumExtensionPack);

  # Helium bundles MV2 uBlock Origin; policy installs uBO Lite — block the duplicate.
  heliumBundledExtensionsToRemove = [
    "blockjmkbacgjkknlgpkjjiijinjdanf" # uBlock Origin (component)
  ];

  chromiumExtensionMeta = lib.listToAttrs (
    map (e: {
      name = e.id;
      value = e.name;
    }) (lib.attrValues chromiumExtensionPack)
  );

  # Default launch flags; vaapiMode is set per-host from gpuType in modules/home.nix.
  chromiumStandardBrowserFlags = {
    wayland = true;
    verticalTabs = true;
    vaapiMode = false;
    extra = [ "--no-default-browser-check" ];
  };

  # vaapiMode: false | "generic" | "nvidia"
  # - nvidia: upstream-recommended bundle for nvidia-vaapi-driver on Wayland
  # - generic: Intel/AMD VA-API (VaapiVideoDecoder only; no encoder for playback)
  #
  # Fallback ladder if blocky GIF/WebM artifacts persist on NVIDIA:
  # 1. [applied] Drop ZeroCopyGL from enableFeatures (see below)
  # 2. [applied] Disable UseChromeOSDirectVideoDecoder (see below)
  # 3. [applied for Helium + Vivaldi] Set vaapiMode = false (software decode;
  #    higher CPU). See softwareDecodeFlagsFile in modules/home.nix — both
  #    still artifacted after rungs 1-2, so they get vaapiMode forced to
  #    false. Chromium proper has not shown the issue and keeps hw decode.
  mkChromiumFlags =
    {
      wayland ? true,
      verticalTabs ? false,
      vaapiMode ? false,
      darkMode ? false,
      extra ? [ ],
    }:
    let
      vaapiFeatures =
        if vaapiMode == "nvidia" then
          [
            "AcceleratedVideoDecodeLinuxGL"
            # ZeroCopyGL omitted: nvidia-vaapi-driver mangles the shared decode
            # buffers, producing blocky GIF/WebM artifacts. Keep GL decode, drop
            # zero-copy so frames are copied (correct) instead of shared (corrupt).
            "VaapiOnNvidiaGPUs"
            "VaapiIgnoreDriverChecks"
          ]
        else if vaapiMode == "generic" then
          [ "VaapiVideoDecoder" ]
        else
          [ ];
      enableFeatures = lib.concatLists [
        (lib.optionals verticalTabs [
          "VerticalTabs"
          "SidePanelPinning"
        ])
        vaapiFeatures
        (lib.optionals darkMode [ "WebUIDarkMode" ])
      ];
      # Chromium only honors the *last* --disable-features flag on the command
      # line, so every disabled feature must be combined into one list/flag
      # rather than emitted as separate --disable-features occurrences.
      disableFeatures = lib.concatLists [
        (lib.optionals (vaapiMode == "nvidia") [ "UseChromeOSDirectVideoDecoder" ])
        # Explicit-sync (linux-drm-syncobj-v1) support in Chromium's Ozone/
        # Wayland backend has the same corruption interaction with the
        # nvidia driver that Hyprland's own explicit sync had to disable
        # for (see hypr.nix). Disable it here too, independent of vaapiMode.
        (lib.optionals wayland [ "WaylandLinuxDrmSyncobj" ])
      ];
      lines =
        lib.optionals wayland [
          "--ozone-platform-hint=wayland"
          "--enable-wayland-ime"
        ]
        ++ lib.optionals (enableFeatures != [ ]) [
          "--enable-features=${lib.concatStringsSep "," enableFeatures}"
        ]
        ++ lib.optionals (vaapiMode == "generic") [ "--ignore-gpu-blocklist" ]
        ++ lib.optionals (disableFeatures != [ ]) [
          "--disable-features=${lib.concatStringsSep "," disableFeatures}"
        ]
        ++ lib.optionals darkMode [ "--force-dark-mode" ]
        ++ extra;
    in
    lib.concatStringsSep "\n" lines;
in
{
  inherit
    chromiumExtensionPack
    chromiumStandardExtensions
    chromiumExtensionMeta
    chromiumStandardBrowserFlags
    heliumBundledExtensionsToRemove
    mkChromiumFlags
    ;
}
