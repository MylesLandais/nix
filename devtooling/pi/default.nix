{
  pkgs,
  lib,
  config,
  ...
}:
let
  fetchNpmTarball = { pkg, version, hash }: pkgs.fetchurl {
    url = "https://registry.npmjs.org/@mariozechner/${pkg}/-/${pkg}-${version}.tgz";
    inherit hash;
  };

  tarballs = {
    coding-agent = fetchNpmTarball { pkg = "pi-coding-agent"; version = "0.65.0"; hash = "sha256-REkPMFr1ZQz83TtEBmoVfVlX+4YauAG2rkGF1Q4G/Gc="; };
    tui          = fetchNpmTarball { pkg = "pi-tui";          version = "0.65.0"; hash = "sha256-Jq+3q0DhPz9+/ob8suOe06ygfSZpGe2N4AZbqqPJCxY="; };
    ai           = fetchNpmTarball { pkg = "pi-ai";           version = "0.65.0"; hash = "sha256-0be4n48lOUczD2m1W7c+j3PC9KfJGuLZ9XoLhEkm19c="; };
    agent        = fetchNpmTarball { pkg = "pi-agent-core";   version = "0.65.0"; hash = "sha256-AuFo5qYWwRjJCOU9ir7QGgZ5h6BwFR5xV54V9JRmDCE="; };
  };

  pi-coding-agent = pkgs.buildNpmPackage {
    pname = "pi-coding-agent";
    version = "0.65.0";

    # Monorepo source provides the package-lock.json for npm deps resolution
    src = pkgs.fetchFromGitHub {
      owner = "badlogic";
      repo = "pi-mono";
      rev = "v0.65.0";
      hash = "sha256-b6WwmN7zFi3iYW+VNG/uZ+804bxLlle31tf5wDoP55U=";
    };

    npmDepsHash = "sha256-PbcHSLRogYLGSs/7pMi7C1FQVARx/2OElt7QXGSQOqw=";

    nativeBuildInputs = with pkgs; [
      pkg-config
      python3
      makeWrapper
    ];

    buildInputs = with pkgs; [
      cairo
      pango
      libjpeg
      giflib
      librsvg
      pixman
    ];

    # Skip TypeScript compilation — use pre-built dist from npm tarballs
    dontNpmBuild = true;

    buildPhase = ''
      runHook preBuild
      # Extract pre-built packages from npm into the monorepo workspace dirs
      tar -xzf ${tarballs.coding-agent} --strip-components=1 -C packages/coding-agent
      tar -xzf ${tarballs.tui}          --strip-components=1 -C packages/tui
      tar -xzf ${tarballs.ai}           --strip-components=1 -C packages/ai
      tar -xzf ${tarballs.agent}        --strip-components=1 -C packages/agent
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/pi-coding-agent
      # Copy the dist and all workspace packages (symlinks in node_modules point here)
      cp -r packages $out/lib/pi-coding-agent/
      cp -r node_modules $out/lib/pi-coding-agent/
      # Rewrite workspace symlinks to point to the new absolute location
      for link in $out/lib/pi-coding-agent/node_modules/@mariozechner/pi-tui \
                  $out/lib/pi-coding-agent/node_modules/@mariozechner/pi-ai \
                  $out/lib/pi-coding-agent/node_modules/@mariozechner/pi-agent-core \
                  $out/lib/pi-coding-agent/node_modules/@mariozechner/pi-coding-agent; do
        if [ -L "$link" ]; then
          target=$(readlink "$link")
          # target is like ../../packages/tui — resolve relative to node_modules/@mariozechner
          resolved=$(realpath --no-symlinks "$out/lib/pi-coding-agent/node_modules/@mariozechner/$target")
          rm "$link"
          ln -s "$resolved" "$link"
        fi
      done
      # Remove broken workspace symlinks we don't need (examples, web-ui, mom, pods)
      for link in $out/lib/pi-coding-agent/node_modules/pi-extension-* \
                  $out/lib/pi-coding-agent/node_modules/pi-web-ui-example \
                  $out/lib/pi-coding-agent/node_modules/@mariozechner/pi-web-ui \
                  $out/lib/pi-coding-agent/node_modules/@mariozechner/pi-mom \
                  $out/lib/pi-coding-agent/node_modules/@mariozechner/pi; do
        [ -L "$link" ] && rm "$link"
      done
      makeWrapper ${pkgs.nodejs}/bin/node $out/bin/pi \
        --add-flags "$out/lib/pi-coding-agent/packages/coding-agent/dist/cli.js"
      runHook postInstall
    '';

    meta = {
      description = "Pi coding agent CLI";
      homepage = "https://github.com/badlogic/pi-mono";
      license = lib.licenses.mit;
      mainProgram = "pi";
    };
  };
in
{
  options = {
    pi.enable = lib.mkEnableOption "Enable pi coding agent module";
  };

  config = lib.mkIf config.pi.enable {
    home.packages = [ pi-coding-agent ];
  };
}
