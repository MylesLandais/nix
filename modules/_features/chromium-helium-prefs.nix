# Helium profile prefs (ext_proxy, vertical tabs) and CDP launcher desktop entry.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.chromiumHeliumPrefs;
in
{
  options.chromiumHeliumPrefs = {
    enable = lib.mkEnableOption "Helium profile activation tweaks and CDP desktop entry";
  };

  config = lib.mkIf cfg.enable {
    # The daily-driver launcher. Upstream ships no usable helium.desktop here
    # (our env-packages wrapper is a bare writeShellScriptBin), so without this
    # the CDP entry below was the only Helium launcher on the system -- every
    # ordinary launch opened port 9222 and let any local CDP client attach and
    # leave tabs sitting in "Paused in debugger".
    home.file.".local/share/applications/helium.desktop".text = ''
      [Desktop Entry]
      Version=1.0
      Name=Helium
      GenericName=Web Browser
      Comment=Helium web browser
      Exec=helium %U
      StartupNotify=true
      StartupWMClass=helium
      Terminal=false
      Icon=helium
      Type=Application
      Categories=Network;WebBrowser;
      MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;x-scheme-handler/unknown;application/xhtml+xml;application/xml;
    '';

    # Automation-only launcher: separate profile so an attached debugger can
    # never touch the daily profile, and no MimeType lines so it is never
    # picked as a URL handler.
    home.file.".local/share/applications/helium-browser-cdp.desktop".text = ''
      [Desktop Entry]
      Version=1.0
      Name=Helium (CDP)
      GenericName=Web Browser
      Comment=Helium with remote debugging for automation (isolated profile)
      Exec=helium --remote-debugging-port=9222 --user-data-dir=${config.xdg.dataHome}/helium-cdp %U
      StartupNotify=true
      Terminal=false
      Icon=helium
      Type=Application
      Categories=Network;WebBrowser;Development;
      # Keep the automation-only profile out of normal app launchers. It must
      # remain available to automation by desktop ID / direct command, but it
      # must never be mistaken for the daily-driver browser.
      NoDisplay=true
    '';

    home.activation.ensureHeliumProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.python3}/bin/python3 ${inputs.self}/scripts/helium-profile-guard.py \
        --data-dir "${config.xdg.configHome}/net.imput.helium" \
        --profile-directory Default --quiet || true
    '';
  };
}
