{ pkgs, ... }:
{
  environment.etc."firefox/policies/policies.json".text = builtins.toJSON {
    policies = {
      EnableMediaDRM = true;

      # Disable local storage (use Bitwarden instead)
      DisablePasswordManager = true;
      DisableDownloadSave = true;
      DisableSavePage = true;
      DisableFormHistory = true;
      DisableBuiltinPDFViewer = false;

      # Force-install extensions
      ExtensionSettings = {
        "ublock-origin@raymondhill.net" = {
          installation_mode = "force_installed";
          default_area = "navbar";
        };
        "bitwarden@browser" = {
          installation_mode = "force_installed";
          default_area = "navbar";
        };
      };

      # Privacy hardening
      DisableFirefoxAccounts = false;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableTelemetry = true;
      DisableFeedbackCommands = true;
      DisableDefaultBrowserCheck = true;

      DNSOverHTTPS = {
        Enabled = true;
        ProviderURL = "https://dns.quad9.net/dns-query";
      };

      Homepage = {
        URL = "about:home";
        Locked = true;
      };
      NewTabPage = "about:home";
      Bookmarks.Enabled = false;

      AppAutoUpdate = false;
      BackgroundAppUpdate = false;
    };
  };

  # Bitwarden native messaging for Firefox
  environment.etc."firefox/native-messaging-hosts/bitwarden.json".text = ''
    {
      "name": "com.8bit.bitwarden",
      "description": "Bitwarden desktop integration",
      "path": "${pkgs.bitwarden-desktop}/bin/bitwarden",
      "type": "stdio",
      "allowed_extensions": ["{446900e4-71c2-419f-a6a7-df9c091e268b}"]
    }
  '';
}
