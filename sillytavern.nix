{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs
, git
}:

buildNpmPackage rec {
  pname = "sillytavern";
  version = "1.12.12";

  src = fetchFromGitHub {
    owner = "SillyTavern";
    repo = "SillyTavern";
    rev = "v${version}";
    hash = "sha256-uy7NxI8SkGZvSle2thjz3W2df7OxdlgKvHMFXlV+bI0=";
  };

  npmDepsHash = "sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"; # TODO: Run nix build and get actual hash

  nativeBuildInputs = [ nodejs git ];

  buildPhase = ''
    runHook preBuild

    # Run webpack compilation as done in Dockerfile
    node ./docker/build-lib.js

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r . $out/

    # Remove unnecessary files to reduce size
    rm -rf $out/docker
    rm -rf $out/tests
    rm -rf $out/.git*

    runHook postInstall
  '';

  meta = with lib; {
    description = "SillyTavern - LLM Frontend for Power Users";
    homepage = "https://github.com/SillyTavern/SillyTavern";
    license = licenses.agpl3Only;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}