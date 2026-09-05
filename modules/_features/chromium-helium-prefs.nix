# Helium profile prefs (ext_proxy, vertical tabs) and CDP launcher desktop entry.
{
  config,
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
      NoDisplay=false
    '';

    home.activation.ensureHeliumProfilePrefs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            pref="$HOME/.config/net.imput.helium/Default/Preferences"
            if [ -f "$pref" ]; then
              ${pkgs.python3}/bin/python3 - "$pref" <<'PY'
      import json, pathlib, sys
      p = pathlib.Path(sys.argv[1])
      data = json.loads(p.read_text())
      changed = False

      services = data.setdefault("helium", {}).setdefault("services", {})
      for key, value in {"enabled": True, "ext_proxy": True, "consented": True}.items():
          if services.get(key) is not value:
              services[key] = value
              changed = True

      vt = data.setdefault("vertical_tabs", {})
      for key, value in {
          "enabled": True,
          "collapsed_state": False,
          "uncollapsed_width": 200,
      }.items():
          if vt.get(key) is not value:
              vt[key] = value
              changed = True

      if changed:
          p.write_text(json.dumps(data, separators=(",", ":")))
          print("Helium: updated profile prefs (ext_proxy, vertical_tabs.enabled)")
      PY
            fi
    '';
  };
}
