# Claude Code — Anthropic's official terminal coding assistant.
#
# Repackaged directly from official binaries published by Anthropic.
# Eliminates external flake dependencies and allows instant version bumps.
{
  lib,
  stdenv,
  fetchurl,
  makeBinaryWrapper,
  autoPatchelfHook,
  procps,
  ripgrep,
  bubblewrap,
  socat,
}:
let
  version = "2.1.328";

  platformMap = {
    "aarch64-darwin" = "darwin-arm64";
    "x86_64-darwin" = "darwin-x64";
    "x86_64-linux" = "linux-x64";
    "aarch64-linux" = "linux-arm64";
  };

  platform =
    platformMap.${stdenv.hostPlatform.system}
      or (throw "Claude Code is not supported on ${stdenv.hostPlatform.system}");

  nativeHashes = {
    "darwin-arm64" = "sha256-6FVHGQ74zZgwM7phsXGUBFpv6gADXaNJ7+q+2GutrMk=";
    "darwin-x64" = "sha256-v0ClVVwB5q/mwCj74Hgvk1gPTwg1/V0TAi4DnsdlB+E=";
    "linux-x64" = "sha256-qYLTgDC5fnUISK3Sy7LfbZpw1VRKIsqbIWo0m6JYZeg=";
    "linux-arm64" = "sha256-MH+LraJ7N9t1U/rHXoYATj2/9akx/8YRtU/nEM4etSE=";
  };

  nativeBinary = fetchurl {
    urls = [
      "https://downloads.claude.ai/claude-code-releases/${version}/${platform}/claude"
      "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}/${platform}/claude"
    ];
    sha256 = nativeHashes.${platform};
  };
in
stdenv.mkDerivation {
  pname = "claude-code";
  inherit version;

  dontUnpack = true;
  # Stripping corrupts the embedded Bun trailer.
  dontStrip = true;

  nativeBuildInputs = [
    makeBinaryWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isElf [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin

    install -m755 ${nativeBinary} $out/bin/.claude-unwrapped

    makeBinaryWrapper $out/bin/.claude-unwrapped $out/bin/claude \
      --inherit-argv0 \
      --set DISABLE_AUTOUPDATER 1 \
      --set DISABLE_INSTALLATION_CHECKS 1 \
      --set USE_BUILTIN_RIPGREP 0 \
      --prefix PATH : ${
        lib.makeBinPath (
          [
            procps
            ripgrep
          ]
          ++ lib.optionals stdenv.hostPlatform.isLinux [
            bubblewrap
            socat
          ]
        )
      }

    runHook postInstall
  '';

  meta = with lib; {
    description = "Claude Code - AI coding assistant in your terminal";
    homepage = "https://www.anthropic.com/claude-code";
    license = licenses.unfree;
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "claude";
  };
}
