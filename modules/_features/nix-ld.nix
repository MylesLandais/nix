# Loader shim for prebuilt, generic-Linux binaries.
#
# NixOS ships a stub at /lib64/ld-linux-x86-64.so.2 that only prints an error,
# so a downloaded upstream binary dies before main(). nix-ld replaces the stub
# with a real loader that resolves libraries from NIX_LD_LIBRARY_PATH.
#
# Needed here by Buzz (pkgs.buzz-desktop), which downloads its own pinned
# Node.js from nodejs.org into ~/.local/share/Buzz/runtimes/ and gates its
# agent-install flow on `node --version` succeeding. Buzz pins an exact patch
# release and offers no override, so pointing it at a nixpkgs node is not an
# option — the downloaded binary simply has to be runnable.
#
# Keep `libraries` minimal: this list is the whole point of the escape hatch
# staying narrow. Widen it only when a specific binary fails on a named
# missing library.
{ pkgs, ... }:
{
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib # libstdc++.so.6, libgcc_s.so.1
      zlib
    ];
  };
}
