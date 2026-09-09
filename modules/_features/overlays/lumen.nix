# CineMaya / Lumen — the app served from stage-edge.
#
# Built from source rather than repackaged from a binary (unlike the other
# overlays here), because Lumen is our own code. It ships as two halves:
#
#   lumen-web  static SPA (Vite 8 + React 19 + Tailwind 4) -> $out is a webroot
#   lumen-lab  Node backend (server.mjs) on :3847 — TMDB search, provider
#              racing, subtitle lookup, stream proxy, watch-party WS relay
#
# The upstream repo is a monorepo whose full tree is ~137 MB for a 1.3 MB app,
# so the source is fetched with sparseCheckout.
# The release pin lives in infra/lumen/version.nix — a release bumps that one
# file (procedure: docs/infra/lumen-releases.md). This overlay only reads it.
_final: prev:
let
  pin = import ../../../infra/lumen/version.nix;
  inherit (pin) rev;

  src = prev.fetchFromGitHub {
    owner = "System-Nebula";
    repo = "maya-unified";
    inherit rev;
    sparseCheckout = [ "apps/lumen" ];
    hash = pin.srcHash;
  };

  # The root package.json declares
  #   "postinstall": "npm --prefix lab install"
  # which reaches the network mid-build and therefore fails in the Nix sandbox.
  # The two halves are built as separate derivations instead, so the hook is
  # stripped rather than satisfied.
  dropPostinstall = ''
    ${prev.jq}/bin/jq 'del(.scripts.postinstall)' package.json > package.json.tmp
    mv package.json.tmp package.json
  '';
in
{
  lumen-web = prev.buildNpmPackage {
    pname = "lumen-web";
    version = pin.version;

    inherit src;
    sourceRoot = "${src.name}/apps/lumen";

    npmDepsHash = pin.webNpmDepsHash;

    postPatch = dropPostinstall;

    # Native toolchain deps (@tailwindcss/oxide, rolldown, lightningcss, oxlint)
    # resolve per-platform from the lockfile, which does carry linux-arm64
    # entries — required, since this is built natively on the aarch64 target.
    npmFlags = [ "--ignore-scripts" ];

    # Upstream's `build` script is `tsc -b && vite build`, but the source has
    # never type-checked: `tsc -b` reports 22 errors (nullability, one unused
    # binding, a verbatimModuleSyntax type-only import, some union widening).
    # They are all type-level — the app has only ever been run via `npm run dev`,
    # which does not type-check, so this was never hit upstream.
    #
    # Run vite directly, which strips types without checking them, rather than
    # patching 22 errors in someone else's source as a side effect of packaging.
    # Fixing them upstream and restoring `npmBuildScript = "build"` is the real
    # fix.
    dontNpmBuild = true;
    dontNpmInstall = true;

    buildPhase = ''
      runHook preBuild
      npm exec -- vite build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      cp -r dist $out
      runHook postInstall
    '';

    meta = {
      description = "CineMaya (Lumen) web frontend";
      platforms = prev.lib.platforms.linux;
    };
  };

  lumen-lab = prev.buildNpmPackage {
    pname = "lumen-lab";
    version = pin.version;

    inherit src;
    sourceRoot = "${src.name}/apps/lumen/lab";

    npmDepsHash = pin.labNpmDepsHash;

    # Pure-JS dependencies (cheerio, undici, ws, tweetnacl, …); nothing to
    # compile and no build script.
    dontNpmBuild = true;
    dontNpmInstall = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r server.mjs scrapers.js anisurgeProviders.js node_modules $out/
      [ -d public ] && cp -r public $out/ || true
      runHook postInstall
    '';

    meta = {
      description = "CineMaya (Lumen) scraper/proxy backend";
      platforms = prev.lib.platforms.linux;
    };
  };
}
