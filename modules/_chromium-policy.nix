{ config, lib, ... }:

with lib;

let
  cfg = config.chromiumPolicies;

  hyprlandClassFor =
    browserName:
    {
      chrome = "^(?i)(google-chrome|chrome)$";
      helium = "^(?i)(helium|chromium)$";
      chromium = "^(?i)(chromium|helium)$";
      vivaldi = "^(?i)vivaldi$";
    }
    .${browserName} or "^(?i)${browserName}$";

  # Common Chromium policies we want across all browsers.
  # These are merged with per-browser policies.
  commonPolicies = {
    # Security defaults
    BlockThirdPartyCookies = false; # too many sites break; selectively manage
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
    SafeBrowsingProtectionLevel = 1; # standard, not enhanced (less data sent)
    UrlKeyedAnonymizedDataCollectionEnabled = false;

    # Chrome Cleanup / safety
    ChromeCleanupEnabled = false;
    ChromeVariations = 1; # 1 = enable critical variations only

    # Extension management
    ExtensionSettings = {
      "*" = {
        installation_mode = "allowed";
        update_url = cwsUpdateUrl;
      };
    };
  };

  cwsUpdateUrl = "https://clients2.google.com/service/update2/crx";
  # Helium rewrites CWS fetches through its proxy; policy update_url must match.

  # Build ExtensionInstallForcelist from extension IDs.
  mkForceList = updateUrl: extIds: map (id: "${id};${updateUrl}") extIds;

  # Generate the full policies JSON for a given browser config.
  mkPoliciesJson =
    browserConfig:
    let
      updateUrl = browserConfig.extensionUpdateUrl;
      extSettings =
        (
          if browserConfig.extensions != null then
            listToAttrs (
              map (id: {
                name = id;
                value = {
                  installation_mode = "force_installed";
                  update_url = updateUrl;
                  override_update_url = true;
                };
              }) browserConfig.extensions
            )
          else
            { }
        )
        // listToAttrs (
          map (id: {
            name = id;
            value = {
              installation_mode = "removed";
            };
          }) (browserConfig.removedExtensions or [ ])
        );
    in
    builtins.toJSON (
      (removeAttrs commonPolicies [ "ExtensionSettings" ])
      // browserConfig.policies
      // {
        ExtensionSettings =
          (
            commonPolicies.ExtensionSettings
            // {
              "*" = commonPolicies.ExtensionSettings."*" // {
                update_url = updateUrl;
              };
            }
          )
          // extSettings;
      }
      // (
        if browserConfig.extensions != null then
          {
            ExtensionInstallForcelist = mkForceList updateUrl browserConfig.extensions;
          }
        else
          { }
      )
    );

  # Build flags file content for a browser.

  mkHyprlandExtraConfig =
    enabledBrowsers:
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
      type = types.attrsOf (
        types.submodule {
          options = {
            enable = mkEnableOption "policies for this browser";

            extensions = mkOption {
              type = types.nullOr (types.listOf types.str);
              default = null;
              description = "Extension IDs to force-install. Null = allow all, empty = block all.";
            };

            removedExtensions = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = ''
                Extension IDs to uninstall and block (installation_mode = removed).
                Use for bundled component extensions that duplicate force_installed ones.
              '';
            };

            extensionUpdateUrl = mkOption {
              type = types.str;
              default = cwsUpdateUrl;
              description = ''
                CRX update URL for force_installed extensions. Helium must use
                https://services.helium.imput.net/ext instead of the Chrome Web Store.
              '';
            };

            policies = mkOption {
              type = types.attrs;
              default = { };
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
                default = [ ];
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
        }
      );
      default = { };
      description = "Per-browser Chromium policy configuration.";
    };
  };

  config = mkIf cfg.enable (
    let
      enabledBrowsers = filterAttrs (_name: b: b.enable) cfg.browsers;

      heliumInitialPreferences = optionalAttrs (enabledBrowsers ? helium) {
        helium = {
          services = {
            enabled = true;
            ext_proxy = true;
            consented = true;
          };
        };
        vertical_tabs = {
          enabled = true;
          collapsed_state = false;
          uncollapsed_width = 200;
        };
      };

      # Generate /etc/$browser/policies/managed/XXXX.json entries
      policyFiles = mapAttrs' (
        _browserName: browserConfig:
        let
          p = browserConfig.policyPath;
        in
        nameValuePair "${p}/policies/managed/nixos-policies.json" {
          text = mkPoliciesJson browserConfig;
        }
      ) enabledBrowsers;

    in
    {
      environment.etc =
        policyFiles
        // optionalAttrs (heliumInitialPreferences != { }) {
          "chromium/initial_preferences".text = builtins.toJSON heliumInitialPreferences;
        };

      chromiumPolicies.hyprlandExtraConfig = mkHyprlandExtraConfig enabledBrowsers;
    }
  );
}
