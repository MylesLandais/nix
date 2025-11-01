{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.firefox;
in
{
  options.programs.firefox = {
    preferences = mkOption {
      type = types.attrs;
      default = {};
      description = "Firefox preferences to set";
    };
  };

  config = mkIf cfg.enable {
    # Firefox user configuration (Home Manager)
    programs.firefox = {
      # User configuration
      profiles.default = {
        id = 0;
        name = "default";
        isDefault = true;
        
        # Extensions from NUR
        extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
          ublock-origin
          bitwarden
          plasma-integration
          darkreader
          privacy-badger
          noscript
        ];
        
        # Firefox preferences - STABILITY FOCUSED
        settings = cfg.preferences // {
          # Tab configuration - tabs on the left (Firefox 136 vertical tabs)
          "sidebar.revamp" = true;                    # Enable sidebar revamp
          "sidebar.verticalTabs" = true;              # Enable vertical tabs
          "sidebar.main.tools" = "verticaltabs";      # Set vertical tabs as main sidebar tool
          "sidebar.position_start" = true;            # Position sidebar on the left
          "sidebar.verticalTabs.width" = 200;         # Set explicit width for vertical tabs
          "browser.tabs.inTitlebar" = 0;              # Move tabs out of titlebar
          
          # DRM and media settings
          "media.eme.enabled" = true;
          "media.eme.apiVisible" = true;
          "media.gmp-widevinecdm.enabled" = true;
          "media.gmp-widevinecdm.visible" = true;
          
          # Privacy and security settings - BALANCED FOR STABILITY
          "privacy.trackingprotection.enabled" = true;
          "privacy.trackingprotection.socialtracking.enabled" = true;
          "privacy.resistFingerprinting" = false;     # DISABLED - can cause rendering issues
          "privacy.firstparty.isolate" = false;        # DISABLED - can break logins
          "privacy.donottrackheader.enabled" = true;
          
          # Login and form settings - LESS RESTRICTIVE
          "signon.rememberSignons" = true;           # ENABLED - for login stability
          "signon.autofillForms" = true;             # ENABLED - for convenience
          "browser.formfill.enable" = true;             # ENABLED - for form stability
          "browser.download.useDownloadDir" = true;     # ENABLED - for normal behavior
          "browser.download.folderList" = 1;            # Default download folder
          "browser.download.manager.showWhenStarting" = true;
          
          # History and session restore - ENABLED FOR STABILITY
          "browser.history_expire_days" = 90;           # Keep history for 90 days
          "browser.history_expire_days.mirror" = 90;
          "browser.sessionstore.resume_from_crash" = true;  # ENABLED - crash recovery
          "browser.sessionstore.resume_session_once" = false;
          
          # Security settings
          "security.ssl.require_safe_negotiation" = true;
          "security.tls.insecure_fallback_hosts" = "";
          "security.tls.version.min" = 3;
          "security.tls.version.max" = 4;
          
          # Performance settings - BALANCED CACHING
          "browser.cache.disk.enable" = true;          # ENABLED - prevents rendering issues
          "browser.cache.memory.enable" = true;
          "browser.cache.disk.capacity" = 256000;      # 256MB disk cache
          "browser.cache.disk.smart_size.enabled" = true; # ENABLED - auto-manage cache
          "browser.cache.disk.smart_size.first_run" = false;
          
          # UI/UX settings
          "browser.startup.page" = 1;
          "browser.newtabpage.enabled" = true;
          "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
          "browser.newtabpage.activity-stream.feeds.snippets" = false;
          "browser.newtabpage.activity-stream.section.highlights.includeBookmarks" = false;
          "browser.newtabpage.activity-stream.section.highlights.includeDownloads" = false;
          "browser.newtabpage.activity-stream.section.highlights.includeVisited" = false;
          
          # Network settings
          "network.dns.disableIPv6" = false;
          "network.http.sendRefererHeader" = 2;
          "network.http.referer.spoofSource" = false;
          "network.http.referer.trimmingPolicy" = 0;
          
          # Extension settings
          "extensions.autoDisableScopes" = 0;
          "extensions.enabledScopes" = 15;
          "extensions.update.enabled" = true;
          "extensions.update.autoUpdateDefault" = false;
          
          # Bitwarden specific settings
          "browser.nativeMessaging.bitwarden" = true;
          "extensions.bitwarden@browser.duckduckgo.com.private" = true;
          "extensions.bitwarden@browser.duckduckgo.com.toolbar" = true;
          
          # Theme and appearance
          "widget.content.gtk-theme-override" = "Kanagawa";
          "ui.systemUsesDarkTheme" = true;
          "devtools.theme" = "dark";
          
          # Experimental features - CONSERVATIVE
          "gfx.webrender.all" = true;
          "layers.acceleration.force-enabled" = false;    # DISABLED - can cause issues
          "media.hardware-video-decoding.force-enabled" = false; # DISABLED - can cause issues
          
          # Disable telemetry and data collection
          "toolkit.telemetry.enabled" = false;
          "toolkit.telemetry.unified" = false;
          "toolkit.telemetry.archive.enabled" = false;
          "experiments.enabled" = false;
          "experiments.supported" = false;
          "browser.ping-centre.telemetry" = false;
          "browser.newtabpage.activity-stream.telemetry" = false;
          "browser.newtabpage.activity-stream.feeds.telemetry" = false;
          "browser.newtabpage.activity-stream.telemetry.ping.endpoint" = "";
          
          # Disable Pocket and other sponsored content
          "extensions.pocket.enabled" = false;
          "browser.newtabpage.activity-stream.showSponsored" = false;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
          "browser.newtabpage.activity-stream.feeds.system.topstories" = false;
          
          # Disable Firefox accounts and sync
          "identity.fxaccounts.enabled" = false;
          "webchannel.allowObject.urlWhitelist" = "";
          
          # Disable default browser checks
          "browser.shell.checkDefaultBrowser" = false;
          "browser.defaultbrowser.notificationbar" = false;
          
          # Disable studies and experiments
          "app.shield.optoutstudies.enabled" = false;
          "extensions.shield-recipe-client.enabled" = false;
          "browser.discovery.enabled" = false;
          
          # Disable crash reports
          "breakpad.reportURL" = "";
          "browser.tabs.crashReporting.sendReport" = false;
          "browser.crashReports.unsubmittedCheck.autoSubmit2" = false;
          
          # Disable health report
          "datareporting.healthreport.uploadEnabled" = false;
          "datareporting.healthreport.service.enabled" = false;
          "datareporting.policy.dataSubmissionEnabled" = false;
          "datareporting.policy.dataSubmissionEnabled.v2" = false;
        };
        
        # Search engines
        search = {
          force = true;
          default = "ddg";
          engines = {
            "ddg" = {
              urls = [{ template = "https://duckduckgo.com/?q={searchTerms}"; }];
              icon = "https://duckduckgo.com/favicon.ico";
              definedAliases = [ "@d" ];
            };
            "google" = {
              urls = [{ template = "https://www.google.com/search?q={searchTerms}"; }];
              icon = "https://www.google.com/favicon.ico";
              definedAliases = [ "@g" ];
            };
            "nix-packages" = {
              urls = [{ template = "https://search.nixos.org/packages?query={searchTerms}"; }];
              icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
              definedAliases = [ "@np" ];
            };
            "nixos-options" = {
              urls = [{ template = "https://search.nixos.org/options?query={searchTerms}"; }];
              icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
              definedAliases = [ "@no" ];
            };
            "home-manager" = {
              urls = [{ template = "https://home-manager-options.extranix.com/?query={searchTerms}"; }];
              icon = "https://nixos.org/favicon.ico";
              definedAliases = [ "@hm" ];
            };
          };
        };
      };
    };

    # Add Bitwarden desktop to user packages for native messaging
    home.packages = with pkgs; [
      bitwarden-desktop
    ];
  };
}