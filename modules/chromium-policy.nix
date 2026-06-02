{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.chromiumPolicies;

  # Hyprland window class patterns per browser key (Helium reports as Helium/Chromium).
  hyprlandClassFor = browserName:
    {
      helium = "^(?i)(helium|chromium)$";
      chromium = "^(?i)(chromium|helium)$";
    }
    .${browserName}
    or "^(?i)${browserName}$";

  # Common Chromium policies we want across all browsers.
  # These are merged with per-browser policies.
  commonPolicies = {
    # Security defaults
    BlockThirdPartyCookies = false;        # too many sites break; selectively manage
    CookiesAllowedForUrls = [
      "https://*.github.com"
      "https://*.nixos.org"
    ];
    PasswordManagerEnabled = true;
    AutoFillEnabled = true;
    SearchSuggestEnabled = true;
    SpellcheckEnabled = true;
    PrintingEnabled = true;

    # Do not prompt to become the default browser (Firefox uses a different key).
    DefaultBrowserSettingEnabled = false;

    # Disable telemetry & data collection
    MetricsReportingEnabled = false;
    SafeBrowsingProtectionLevel = 1;       # standard, not enhanced (less data sent)
    UrlKeyedAnonymizedDataCollectionEnabled = false;

    # Chrome Cleanup / safety
    ChromeCleanupEnabled = false;
    ChromeVariations = 1;                  # 1 = enable critical variations only

    # Extension management
    ExtensionSettings = {
      "*" = {
        installation_mode = "allowed";
        minimum_version_required = "";
        update_url = "https://clients2.google.com/service/update2/crx";
      };
    };
  };

  # Extension IDs mapped to human names for readability.
  # These are Chromium Web Store IDs.
  extensionMeta = {
    "ddkjiahejlhfcafbddmgiahcphecmpfh" = "uBlock Origin Lite";   # MV3
    "cjpalhdlnbpafiamejdnhcphjbkeiagm" = "uBlock Origin";        # MV2 (Chromium)
    "nngceckbapebfimnlniiiahkandclblb" = "Bitwarden";
    "eimadpbcbfnmbkopoojfekhnkhdbieeh" = "Dark Reader";
    "dbnnaeemhnkgddpbkfmbgglgpgmhemdj" = "Tabli";
    "ldpochfccmkkmhdbclfhpkoapfpopohp" = "Sidebery";            # Vertical tabs + tab manager
    "hkgfoiooedgoejojocmhlaklpbjgoaco" = "MarkDownload";
    "aomjjhallfgjeglblejbfpaicpbiebcp" = "Vimium C";
    "ghbmnnjooekpmoecnnnilnnbdlolhkhi" = "Google Docs Offline";
    "mnjggcdmjocbbbhaepdchnknhmbkhfif" = "Enhancer for YouTube";
    "gighmmpiobklfepjocnamgkkbiglidom" = "AdBlock";
  };

  # Build ExtensionInstallForcelist from extension IDs.
  mkForceList = extIds: map (id:
    let
      name = extensionMeta.${id} or id;
    in
    "${id};https://clients2.google.com/service/update2/crx"
  ) extIds;

  # Generate the full policies JSON for a given browser config.
  mkPoliciesJson = browserConfig:
    let
      extSettings = if browserConfig.extensions != null then
        # Build per-extension settings for force-installed extensions.
        listToAttrs (map (id: {
          name = id;
          value = {
            installation_mode = "force_installed";
            minimum_version_required = "";
            update_url = "https://clients2.google.com/service/update2/crx";
          };
        }) browserConfig.extensions)
      else
        commonPolicies.ExtensionSettings;
    in
    builtins.toJSON (
      (removeAttrs commonPolicies [ "ExtensionSettings" ])
      // browserConfig.policies
      // {
        ExtensionSettings = extSettings;
      }
      // (if browserConfig.extensions != null then {
        ExtensionInstallForcelist = mkForceList browserConfig.extensions;
      } else {})
    );

  # Build flags file content for a browser.
  mkFlagsContent = browserConfig:
    (lib.optional (browserConfig.flags.wayland) ''
      --ozone-platform-hint=wayland
      --enable-wayland-ime
    '')
    ++ (lib.optional browserConfig.flags.verticalTabs ''
      --enable-features=VerticalTabs,SidePanelPinning
    '')
    ++ (lib.optional browserConfig.flags.vaapi ''
      --enable-features=VaapiVideoDecoder,VaapiVideoEncoder
      --ignore-gpu-blocklist
    '')
    ++ (lib.optional browserConfig.flags.darkMode ''
      --force-dark-mode
      --enable-features=WebUIDarkMode
    '')
    ++ (lib.optional (browserConfig.flags.extra != [])
      (lib.concatStringsSep "\n" browserConfig.flags.extra)
    );

  mkHyprlandExtraConfig = enabledBrowsers:
    concatStrings (
      mapAttrsToList (
        browserName: browserConfig:
        optionalString browserConfig.hyprlandRules ''
          hl.window_rule({ opacity = 1.0, no_blur = true, match = { class = "${hyprlandClassFor browserName}" } })
        ''
      ) enabledBrowsers
    );
in
{
  options.chromiumPolicies = {
    enable = mkEnableOption "chromium-policy module";

    hyprlandExtraConfig = mkOption {
      type = types.str;
      readOnly = true;
      description = "Hyprland Lua window_rule snippets for enabled Chromium browsers.";
    };

    browsers = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          enable = mkEnableOption "policies for this browser";

          extensions = mkOption {
            type = types.nullOr (types.listOf types.str);
            default = null;
            description = "Extension IDs to force-install. Null = allow all, empty = block all.";
          };

          policies = mkOption {
            type = types.attrs;
            default = {};
            description = "Additional Chromium policies to merge (overrides common defaults).";
          };

          flags = {
            wayland = mkOption {
              type = types.bool;
              default = true;
              description = "Enable Wayland support flags.";
            };
            verticalTabs = mkOption {
              type = types.bool;
              default = false;
              description = "Enable vertical tabs / side panel.";
            };
            vaapi = mkOption {
              type = types.bool;
              default = false;
              description = "Enable VA-API hardware video decoding.";
            };
            darkMode = mkOption {
              type = types.bool;
              default = false;
              description = "Force dark mode.";
            };
            extra = mkOption {
              type = types.listOf types.str;
              default = [];
              description = "Extra command-line flags.";
            };
          };

          hyprlandRules = mkOption {
            type = types.bool;
            default = true;
            description = "Add Hyprland window rules for this browser.";
          };

          policyPath = mkOption {
            type = types.str;
            default = browserName;
            description = ''
              Subpath under /etc/ where policies are written. Defaults to the
              browser name. Examples: "chromium", "opt/chrome", "helium".
            '';
          };
        };
      });
      default = {};
      description = "Per-browser Chromium policy configuration.";
    };
  };

  config = mkIf cfg.enable (
    let
      enabledBrowsers = filterAttrs (name: b: b.enable) cfg.browsers;

      # Generate /etc/$browser/policies/managed/XXXX.json entries
      policyFiles = mapAttrs' (browserName: browserConfig:
        let p = browserConfig.policyPath; in
        nameValuePair "${p}/policies/managed/nixos-policies.json" {
          text = mkPoliciesJson browserConfig;
        }
      ) enabledBrowsers;

    in
    {
      environment.etc = policyFiles;

      chromiumPolicies.hyprlandExtraConfig = mkHyprlandExtraConfig enabledBrowsers;
    }
  );
}
