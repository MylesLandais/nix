# Shared Chromium / Helium extension IDs and launch flags.
{ lib }:
let
  chromiumStandardExtensions = [
    "ddkjiahejlhfcafbddmgiahcphecmpfh" # uBlock Origin Lite (MV3)
    "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
    "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader
    "aomjjhallfgjeglblejbfpaicpbiebcp" # Vimium C
    "hkgfoiooedgoejojocmhlaklpbjgoaco" # MarkDownload
  ];

  mkChromiumFlags =
    {
      wayland ? true,
      verticalTabs ? false,
      vaapi ? false,
      darkMode ? false,
      extra ? [ ],
    }:
    let
      enableFeatures =
        lib.concatLists [
          (lib.optionals verticalTabs [
            "VerticalTabs"
            "SidePanelPinning"
          ])
          (lib.optionals vaapi [
            "VaapiVideoDecoder"
            "VaapiVideoEncoder"
          ])
          (lib.optionals darkMode [ "WebUIDarkMode" ])
        ];
      lines =
        lib.optionals wayland [
          "--ozone-platform-hint=wayland"
          "--enable-wayland-ime"
        ]
        ++ lib.optionals (enableFeatures != [ ]) [
          "--enable-features=${lib.concatStringsSep "," enableFeatures}"
        ]
        ++ lib.optionals vaapi [ "--ignore-gpu-blocklist" ]
        ++ lib.optionals darkMode [ "--force-dark-mode" ]
        ++ extra;
    in
    lib.concatStringsSep "\n" lines;
in
{
  inherit chromiumStandardExtensions mkChromiumFlags;
}
