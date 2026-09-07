# PCSX2 stable release fast-path.
#
# nixpkgs intentionally remains the owner of the build recipe and dependency
# integration.  We vendor only the two independently moving upstream inputs so
# a stable release can be consumed before the corresponding nixpkgs update lands:
# the immutable PCSX2 tag and an exact pcsx2_patches snapshot.
_final: prev:

let
  version = "2.8.0";

  source = prev.fetchFromGitHub {
    pname = "pcsx2-source";
    owner = "PCSX2";
    repo = "pcsx2";
    tag = "v${version}";
    hash = "sha256-qXOcGe5zLmX0vfr5+7tg2KbIVXko99BrfMK95KeyAuA=";
  };

  patchesRev = "6ed7b62cf1d7dacf11e9bf64e193934e899808d0";
  patches = prev.fetchFromGitHub {
    owner = "PCSX2";
    repo = "pcsx2_patches";
    rev = patchesRev;
    hash = "sha256-FvqX9BVm0wIB0OCZR79INzGfUiSs3DOMMO2RzSNAU3s=";
  };
in
{
  pcsx2 = prev.pcsx2.overrideAttrs (oldAttrs: {
    inherit version;
    src = source;

    # New mandatory dependency in 2.8.0; the 2.6.3 nixpkgs recipe predates it.
    buildInputs = (oldAttrs.buildInputs or [ ]) ++ [ prev.rapidyaml ];

    # The nixpkgs recipe closes over its own patches snapshot in postInstall,
    # so replace that small phase to make our vendored snapshot authoritative.
    postInstall = ''
      install -Dm644 $src/pcsx2-qt/resources/icons/AppIcon64.png $out/share/icons/hicolor/64x64/apps/PCSX2.png
      install -Dm644 $src/.github/workflows/scripts/linux/pcsx2-qt.desktop $out/share/applications/PCSX2.desktop

      zip -jq $out/share/PCSX2/resources/patches.zip ${patches}/patches/*
      strip-nondeterminism $out/share/PCSX2/resources/patches.zip
    '';

    passthru =
      builtins.removeAttrs (oldAttrs.passthru or { }) [
        "pcsx2_patches"
        "updateScript"
      ]
      // {
        pcsx2_patches = patches;
        vendorPins = {
          inherit version patchesRev;
          sourceTag = "v${version}";
          sourceHash = source.outputHash;
          patchesHash = patches.outputHash;
        };
      };
  });
}
