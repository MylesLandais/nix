{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs
, git
}:

buildNpmPackage rec {
  pname = "sillytavern";
  version = "1.13.5";

  src = fetchFromGitHub {
    owner = "SillyTavern";
    repo = "SillyTavern";
    rev = "release";
    hash = "sha256-0nz05vw11im58cqnqcv4ny2p478av88v306akqkjg7z6jzsp5znx";
  };

  npmDepsHash = "sha256-0nz05vw11im58cqnqcv4ny2p478av88v306akqkjg7z6jzsp5znx";

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