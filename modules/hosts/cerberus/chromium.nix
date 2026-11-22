{ inputs, ... }:
{
  flake.modules.nixos.cerberus =
    # Cerberus Chromium-family browser policies and the Lamia native-messaging host.
    _:
    let
      chromiumBrowsers = inputs.self.lib.chromiumBrowsers;
      inherit (chromiumBrowsers)
        chromiumStandardExtensions
        heliumBundledExtensionsToRemove
        ;
    in
    {
      # Developer Lamia Browser Adapter. Nixpkgs Chromium resolves native hosts
      # through this system registry rather than Chrome's per-user registry.
      environment.etc."chromium/native-messaging-hosts/org.lamia.browser.json".text = builtins.toJSON {
        name = "org.lamia.browser";
        description = "Lamia Browser Adapter development host";
        path = "/home/warby/Workspace-git/maya-unified/scripts/lamia-browser-host-dev.sh";
        type = "stdio";
        allowed_origins = [ "chrome-extension://mlpcnheempoikdefoabobmilgdnicdlm/" ];
      };

      # Chromium-based browser policies (Helium, Chromium, etc.)
      # flags.vaapi here is metadata only; launch flags come from HM *-flags.conf
      # with vaapiMode = "nvidia" (see modules/aspects/desktop/base/default.nix + gpuType in cerberus HM).
      chromiumPolicies = {
        enable = true;
        browsers = {
          chrome = {
            enable = true;
            policyPath = "opt/chrome";
            extensions = chromiumStandardExtensions;
            flags = {
              verticalTabs = false;
              vaapi = true;
              wayland = true;
            };
          };
          helium = {
            enable = true;
            # Helium AppImage sandbox maps /etc/chromium into the bwrap container
            # so policies must go through the chromium path for the sandbox.
            # Its binary reads only /etc/chromium/policies, which nixpkgs Chromium
            # also reads, so Chromium inherits this file (no separate chromium
            # entry is possible). Chromium installs the forced extensions through
            # Helium's proxy fine; the removed ID is Helium-only and a no-op there.
            policyPath = "chromium";
            extensionUpdateUrl = "https://services.helium.imput.net/ext";
            extensions = chromiumStandardExtensions;
            removedExtensions = heliumBundledExtensionsToRemove;
            flags = {
              verticalTabs = true;
              vaapi = true;
              wayland = true;
            };
          };
          vivaldi = {
            enable = true;
            policyPath = "opt/vivaldi";
            extensions = chromiumStandardExtensions;
            flags = {
              verticalTabs = true;
              vaapi = true;
              wayland = true;
            };
          };
        };
      };
    };
}
