{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.firefox-system;
  bitwardenNativeMessagingHost = pkgs.writeText "bitwarden.json" ''
    {
      "name": "com.8bit.bitwarden",
      "description": "Bitwarden desktop integration",
      "path": "${pkgs.bitwarden-desktop}/bin/bitwarden-desktop",
      "type": "stdio",
      "allowed_extensions": ["{446900e4-71c2-419f-a6a7-df9c091e268b}"]
    }
  '';
in
{
  options.programs.firefox-system = {
    enable = mkEnableOption "Firefox system-wide configuration";
    
    policies = mkOption {
      type = types.attrs;
      default = {};
      description = "Firefox policies to enforce";
    };
  };

  config = mkIf cfg.enable {
    # Firefox system-wide policies
    environment.etc."firefox/policies/policies.json".text = builtins.toJSON {
      policies = cfg.policies // {
        # Enable DRM content
        EnableMediaDRM = true;
        
        # Disable all saving functionality
        DisablePasswordManager = true;
        DisableDownloadSave = true;
        DisableSavePage = true;
        DisableFormHistory = true;
        DisableBuiltinPDFViewer = false;
        
        # Extension management
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
        
        # Security and privacy policies
        DisableFirefoxAccounts = false;
        DisableFirefoxStudies = true;
        DisablePocket = true;
        DisableTelemetry = true;
        DisableFeedbackCommands = true;
        DisableDefaultBrowserCheck = true;
        
        # Network and security
        DNSOverHTTPS = {
          Enabled = true;
          ProviderURL = "https://dns.quad9.net/dns-query";
        };
        
        # Homepage and new tab
        Homepage = {
          URL = "about:home";
          Locked = true;
        };
        NewTabPage = "about:home";
        
        # Browser behavior
        Bookmarks = {
          Enabled = false;
        };
        
        # Update policies
        AppAutoUpdate = false;
        BackgroundAppUpdate = false;
      };
    };

    # Native messaging host for Bitwarden
    environment.etc."firefox/native-messaging-hosts/bitwarden.json".source = bitwardenNativeMessagingHost;
    
    # Ensure Bitwarden desktop is available system-wide
    environment.systemPackages = with pkgs; [
      bitwarden-desktop
    ];
  };
}