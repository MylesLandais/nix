# Buzz (block/buzz) — Block's Tauri v2 workspace for humans and AI agents.
#
# Repackaged from the official .deb: upstream ships no Nix packaging (their Nix
# proposal explicitly excludes the desktop app), and the AppImage is a dead end
# here — block/buzz#2604 is it failing on NixOS for want of libzstd.so.1.
# Building from source would mean the React frontend, the Tauri shell and six
# Rust sidecar crates, which is not a reasonable price for installing an app.
_final: prev: {
  buzz-desktop = prev.callPackage (
    {
      lib,
      stdenv,
      fetchurl,

      autoPatchelfHook,
      dpkg,
      makeWrapper,
      wrapGAppsHook3,

      alsa-lib,
      bash,
      cairo,
      dbus,
      gdk-pixbuf,
      git,
      glib,
      gst_all_1,
      gtk3,
      libayatana-appindicator,
      librsvg,
      libsoup_3,
      openssl,
      pango,
      webkitgtk_4_1,
      xdg-utils,
      xdotool,
      zstd,
    }:
    let
      gstPlugins = with gst_all_1; [
        gstreamer
        gst-plugins-base
        gst-plugins-good
        gst-plugins-bad
        gst-libav
      ];

      # The sidecars upstream treats as user-facing: README lists buzz-cli (shipped
      # as `buzz`), buzz-acp, buzz-agent and buzz-dev-mcp as the "Agent surface",
      # and git-credential-nostr under "Git & pairing". buzz-backend-kubernetes is
      # an implementation backend and is deliberately absent — it stays in libexec.
      publicSidecars = [
        "buzz"
        "buzz-acp"
        "buzz-agent"
        "buzz-dev-mcp"
        "git-credential-nostr"
      ];
    in
    stdenv.mkDerivation (finalAttrs: {
      pname = "buzz-desktop";
      version = "0.5.8";

      src = fetchurl {
        url = "https://github.com/block/buzz/releases/download/desktop-v${finalAttrs.version}/Buzz_${finalAttrs.version}_amd64.deb";
        # Matches the sha256 digest GitHub reports for the release asset itself.
        hash = "sha256-ymeoHCx16QizgDmmVxz4eqOBEqDvBogfxQBJqLC1jGc=";
      };

      # No unpackPhase needed: dpkg's setup hook extracts .deb sources into root/,
      # which stdenv then picks as sourceRoot, leaving usr/ in the build dir.
      nativeBuildInputs = [
        autoPatchelfHook
        dpkg
        makeWrapper
        wrapGAppsHook3
      ];

      buildInputs = [
        alsa-lib
        cairo
        dbus
        gdk-pixbuf
        glib
        gtk3
        libayatana-appindicator
        librsvg
        libsoup_3
        openssl
        pango
        webkitgtk_4_1
        xdotool
        zstd
        (lib.getLib stdenv.cc.cc)
      ]
      ++ gstPlugins;

      # The tray icon library is dlopen'd rather than DT_NEEDED, so autoPatchelfHook
      # cannot discover it from buildInputs — it has to be forced into the RUNPATH.
      runtimeDependencies = [ libayatana-appindicator ];

      installPhase = ''
        runHook preInstall

        # Take the whole upstream tree first so a future usr/lib or resource
        # directory is not silently dropped, then relocate the binaries.
        mkdir -p "$out"
        cp -a usr/. "$out/"

        mkdir -p "$out/libexec/buzz-desktop"
        mv "$out/bin/"* "$out/libexec/buzz-desktop/"

        for bin in ${lib.escapeShellArgs publicSidecars}; do
          ln -s "../libexec/buzz-desktop/$bin" "$out/bin/$bin"
        done

        runHook postInstall
      '';

      # Left to itself wrapGAppsHook3 would wrap both bin/ and libexec/, double-
      # wrapping the GUI. Wrap it once, by hand, and leave the CLI sidecars as bare
      # symlinks — they have no use for a GTK/GStreamer environment. Wrapping the
      # libexec binary directly (not a bin/ symlink) keeps /proc/self/exe inside
      # libexec, which is how Buzz locates its sibling sidecars at runtime.
      dontWrapGApps = true;

      postFixup = ''
        makeWrapper \
          "$out/libexec/buzz-desktop/buzz-desktop" \
          "$out/bin/buzz-desktop" \
          "''${gappsWrapperArgs[@]}" \
          --prefix PATH : "${
            lib.makeBinPath [
              bash
              git
              xdg-utils
            ]
          }" \
          --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "${lib.makeSearchPath "lib/gstreamer-1.0" gstPlugins}"
      '';

      meta = {
        description = "Workspace where humans and AI agents collaborate";
        homepage = "https://github.com/block/buzz";
        license = lib.licenses.asl20;
        sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
        platforms = [ "x86_64-linux" ];
        mainProgram = "buzz-desktop";
      };
    })
  ) { };
}
