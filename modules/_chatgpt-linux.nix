{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  makeWrapper,
  python3,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  coreutils,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  glibc,
  gtk3,
  libGL,
  libappindicator-gtk3,
  libdrm,
  libgbm,
  libnotify,
  libpulseaudio,
  libsecret,
  libusb1,
  libuuid,
  libxcb,
  libxkbcommon,
  libxshmfence,
  libx11,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libxscrnsaver,
  libxtst,
  nspr,
  nss,
  pango,
  pipewire,
  systemdLibs,
  vulkan-loader,
  wayland,
  xdg-utils,
  zlib,
}:

let
  runtimeLibs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libGL
    libappindicator-gtk3
    libdrm
    libgbm
    libnotify
    libpulseaudio
    libsecret
    libusb1
    libuuid
    libxcb
    libxkbcommon
    libxshmfence
    libx11
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxscrnsaver
    libxtst
    nspr
    nss
    pango
    pipewire
    stdenv.cc.cc.lib
    systemdLibs
    vulkan-loader
    wayland
    zlib
  ];
in
stdenv.mkDerivation (_finalAttrs: {
  pname = "chatgpt-linux";
  version = "26.901.31953";

  src = fetchurl {
    # This is OpenAI's official x64 Linux preview package. The stable apt URL is
    # intentionally content-pinned by the hash below; bump version + hash together.
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb";
    hash = "sha256-K7RSK+h33mwX5fTAcbBuxkiCsd0JqPC9IErwI6t1bZw=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
    python3
  ];

  buildInputs = runtimeLibs;

  # The vendor archive carries optional Qt desktop shims without declaring Qt as
  # a Debian dependency, plus musl alternatives beside the glibc Node binaries.
  # Neither set is loadable on this GTK/glibc build; keep every other ELF strict.
  autoPatchelfIgnoreMissingDeps = [
    "libQt5Core.so.5"
    "libQt5Gui.so.5"
    "libQt5Widgets.so.5"
    "libQt6Core.so.6"
    "libQt6Gui.so.6"
    "libQt6Widgets.so.6"
    "libc.musl-x86_64.so.1"
  ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p unpack "$out"
    # The archive contains privileged package metadata that is irrelevant in the
    # Nix store. Extract the payload without preserving its Debian ownership/modes.
    dpkg --fsys-tarfile "$src" \
      | tar --extract --directory=unpack --no-same-owner --no-same-permissions
    mv unpack/usr/* "$out"/

    # detect-libc (bundled inside app.asar, pulled in by @parcel/watcher when the
    # git repo watcher starts) probes the libc family in three steps. Both of the
    # steps that succeed on ordinary distros fail here:
    #
    #   1. It reads only the first 2048 bytes of /proc/self/exe and follows
    #      PT_INTERP. autoPatchelfHook relocates PT_INTERP into a LOAD segment
    #      appended at the end of this ~280MB binary, so the offset falls outside
    #      the buffer and the probe yields an empty string.
    #   2. It reads /usr/bin/ldd, which does not exist on NixOS.
    #
    # That leaves step 3, process.report.getReport(), which traps (SIGILL) inside
    # node::GetNodeReport on a worker thread and takes the whole app down --
    # reproducibly, moments after "[git-repo-watcher] Starting git repo watcher".
    #
    # Disable the report probe so detect-libc falls through to its `getconf
    # GNU_LIBC_VERSION` / `ldd --version` fallback, which the wrapper PATH below
    # satisfies via glibc.bin. The edit preserves byte length so the surrounding
    # asar offsets and the app.asar.unpacked mapping stay valid; no repack needed.
    python3 -c 'import sys; t=sys.argv[1]; old=b"if (isLinux() && process.report) {"; new=b"if (isLinux() && false         ) {"; assert len(old)==len(new); d=open(t,"rb").read(); assert d.count(old)==1, "detect-libc report probe not found exactly once"; f=open(t,"r+b"); f.seek(d.index(old)); f.write(new); f.close()' \
      "$out/lib/chatgpt/resources/app.asar"

    # The Debian symlink enters a /bin/sh launcher. Use a Nix wrapper around the
    # real executable so GUI launches also see xdg-open and the bundled libraries.
    rm "$out/bin/chatgpt"
    makeWrapper "$out/lib/chatgpt/ChatGPT" "$out/bin/chatgpt" \
      --prefix PATH : ${
        lib.makeBinPath [
          coreutils
          glibc.bin
          xdg-utils
        ]
      } \
      --prefix LD_LIBRARY_PATH : "$out/lib/chatgpt:${lib.makeLibraryPath runtimeLibs}" \
      --add-flags "--password-store=basic" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-wayland-ime=true}}"

    substituteInPlace "$out/share/applications/chatgpt.desktop" \
      --replace-fail "Exec=chatgpt" "Exec=$out/bin/chatgpt"

    # Chrome control depends on assets outside app.asar. Keep this assertion in
    # the package so a future upstream layout change cannot silently drop it.
    marketplace="$out/lib/chatgpt/resources/plugins/openai-bundled/.agents/plugins/marketplace.json"
    chrome_plugin="$out/lib/chatgpt/resources/plugins/openai-bundled/plugins/chrome"
    test -f "$marketplace"
    grep -q '"name"[[:space:]]*:[[:space:]]*"chrome"' "$marketplace"
    test -f "$chrome_plugin/.codex-plugin/plugin.json"
    test -f "$chrome_plugin/scripts/browser-client.mjs"
    test -x "$chrome_plugin/extension-host/linux/x64/extension-host"

    runHook postInstall
  '';

  meta = {
    description = "Official ChatGPT desktop app for Linux";
    homepage = "https://developers.openai.com/codex/app";
    license = lib.licenses.unfree;
    mainProgram = "chatgpt";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
