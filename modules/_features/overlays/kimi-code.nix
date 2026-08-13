# Kimi Code — the standalone CLI (web UI, agent-core-v2, plugin marketplace).
#
# Upstream ships per-platform zip releases containing a single Bun-compiled
# binary named `kimi`. Repackaged with the same boring binary-repackage
# pattern as buzz-desktop.
#
# Replaces the legacy kimi-cli 1.x line entirely: this package provides both
# bin/kimi (primary) and bin/kimi-code (explicit alias). Pin stays at 0.34.0
# deliberately — do not float to main; bump with a hash refresh per release.
_final: prev: {
  kimi-code = prev.callPackage (
    {
      lib,
      stdenv,
      fetchurl,
      unzip,
      autoPatchelfHook,
    }:
    stdenv.mkDerivation (finalAttrs: {
      pname = "kimi-code";
      version = "0.34.0";

      src = fetchurl {
        url =
          "https://github.com/MoonshotAI/kimi-code/releases/download/"
          + "%40moonshot-ai/kimi-code%40${finalAttrs.version}/"
          + "kimi-code-linux-x64.zip";
        # Matches the sha256 digest GitHub reports for the release asset itself.
        hash = "sha256-iFWH8gpR2U3KGPyb/xEkZULAF/t6xFmpaTu6o8pnsZk=";
      };

      nativeBuildInputs = [
        unzip
        autoPatchelfHook
      ];
      buildInputs = [ (lib.getLib stdenv.cc.cc) ];

      dontUnpack = true;
      dontStrip = true;

      installPhase = ''
        runHook preInstall

        mkdir -p "$TMPDIR/unpack" "$out/libexec/kimi-code"
        unzip -q "$src" -d "$TMPDIR/unpack"

        install -m 0755 "$TMPDIR/unpack/kimi" "$out/libexec/kimi-code/kimi"

        mkdir -p "$out/bin"
        ln -s "$out/libexec/kimi-code/kimi" "$out/bin/kimi"
        ln -s "$out/libexec/kimi-code/kimi" "$out/bin/kimi-code"

        runHook postInstall
      '';

      meta = {
        description = "Kimi Code CLI (web UI and agent-core-v2 successor to kimi-cli)";
        homepage = "https://github.com/MoonshotAI/kimi-code";
        license = lib.licenses.asl20;
        sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
        platforms = [ "x86_64-linux" ];
        mainProgram = "kimi";
      };
    })
  ) { };
}
