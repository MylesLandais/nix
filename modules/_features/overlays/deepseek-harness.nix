# DeepSeek Harness (`dsh`) — DeepSeek's open-source agent harness.
#
# Vendored rather than taken as a flake input. Two community flakes exist
# (luochen1990/deepseek-harness-flake, apphousero/deepseek-harness-flake), but
# `dsh` is a plugin host that runs shell and filesystem tools on this machine, so
# the dependency set is worth owning outright rather than inheriting from an
# unaudited third party.
#
# Packaged as a fixed-output derivation rather than buildNpmPackage, which is a
# deliberate departure from the other npm overlays here (see lumen.nix). dsh
# fans out into ~40 scoped @deepseek-ai/* packages, and `npm install
# --package-lock-only` against that graph does not terminate in practice — it ran
# 50 minutes at 100% CPU and 3.5 GB RSS without emitting a lockfile, so there is
# no lock to commit and therefore no npmDepsHash to compute. luochen1990's flake
# reached the same conclusion and also uses hashed FODs.
#
# The outputHash below is the pin: the build gets network access, but any change
# in the resolved dependency closure changes the hash and fails the build loudly.
#
# To bump: change `version`, set outputHash to lib.fakeHash, rebuild, and paste
# the hash Nix reports. Expect the hash to also shift when nixpkgs bumps nodejs,
# since native addons are compiled against it inside the FOD.
_final: prev:
let
  version = "0.1.0-rc.7";

  nodeModules = prev.stdenvNoCC.mkDerivation {
    pname = "deepseek-harness-node-modules";
    inherit version;

    nativeBuildInputs = with prev; [
      nodejs
      cacert
      # dsh depends on node-pty and node-addon-require-builtin, which are native
      # addons: install scripts must actually run, so node-gyp's toolchain has to
      # be present. This is why the FOD cannot use --ignore-scripts.
      python3
      node-gyp
      pkg-config
      gnumake
      stdenv.cc
    ];

    dontUnpack = true;

    buildPhase = ''
      export HOME=$TMPDIR
      export npm_config_cache=$TMPDIR/npm-cache
      # Point node-gyp at the nixpkgs headers so it does not try to fetch a
      # tarball from nodejs.org mid-build.
      export npm_config_nodedir=${prev.nodejs}

      mkdir -p $out
      npm install --prefix $out --no-audit --no-fund --omit=dev \
        @deepseek-ai/dsh@${version}
    '';

    installPhase = ''
      # npm writes the *output store path* into node_modules/.package-lock.json
      # as the project "name". For a fixed-output derivation that is circular:
      # the store path contains the hash, so the content depends on the hash
      # which depends on the content, and the build never converges — it
      # produced a fresh hash on every run until this file was removed. Nothing
      # reads it at runtime.
      rm -f $out/node_modules/.package-lock.json
      rm -f $out/package.json $out/package-lock.json $out/.package-lock.json
      find $out -name '.npmrc' -delete
    '';

    # A fixed-output derivation must be byte-identical to what npm produced, and
    # the default fixup phase is not: it shrinks RPATHs and rewrites shebangs in
    # the prebuilt addons, which both destabilises outputHash between runs and
    # actively corrupts things — it rewrote koffi's
    #   #!/usr/bin/env -S node --no-warnings
    # to "env -S  --no-warnings", dropping the interpreter. The npm-shipped
    # binaries are already self-contained prebuilds; leave them alone.
    dontFixup = true;
    dontStrip = true;
    dontPatchELF = true;
    dontPatchShebangs = true;

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-3nqfbGsR9UxWmLRJEbx6nYET1Q0iKBZlbPza6OpNCa8=";
  };
in
{
  deepseek-harness = prev.stdenvNoCC.mkDerivation {
    pname = "deepseek-harness";
    inherit version;

    nativeBuildInputs = [ prev.makeWrapper ];
    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib
      cp -r ${nodeModules}/node_modules $out/lib/

      # dsh resolves its plugins by walking node_modules at runtime, so the tree
      # has to stay intact and the entrypoint has to run from inside it — a bare
      # symlink into node_modules/.bin loses that context.
      #
      # --expose-internals is mandatory, not a nicety: cordis-plugin-hmr is in
      # the default profile stack and throws "--expose-internals is required for
      # HMR service" during boot without it, so *every* profile fails to start.
      # This is the "expose Node internals" step both upstream flakes perform.
      makeWrapper ${prev.nodejs}/bin/node $out/bin/dsh \
        --add-flags "--expose-internals" \
        --add-flags "$out/lib/node_modules/@deepseek-ai/dsh/lib/bin.js" \
        --prefix PATH : ${
          prev.lib.makeBinPath (
            with prev;
            [
              nodejs
              # Plugin subprocesses shell out for the bash/fs/web tools; without
              # these on PATH the tools fail at runtime rather than at startup.
              bash
              coreutils
              git
              ripgrep
            ]
          )
        }

      runHook postInstall
    '';

    meta = {
      description = "DeepSeek Harness (dsh) — plugin-based agent harness";
      homepage = "https://github.com/deepseek-ai/deepseek-harness";
      license = prev.lib.licenses.bsd3;
      mainProgram = "dsh";
      platforms = prev.lib.platforms.linux;
    };
  };
}
