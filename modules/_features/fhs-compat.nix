# FHS compatibility shims for prebuilt third-party software.
#
# Both entries below exist for Buzz (pkgs.buzz-desktop), which downloads and
# shells out to generic-Linux tooling that assumes a conventional filesystem.
# Keep this module narrow: each shim should name the concrete thing that needs
# it, so it stays reviewable rather than drifting into a general FHS emulation.
{ pkgs, ... }:
{
  # NixOS ships a stub at /lib64/ld-linux-x86-64.so.2 that only prints an error,
  # so a downloaded upstream binary dies before main(). nix-ld replaces the stub
  # with a real loader that resolves libraries from NIX_LD_LIBRARY_PATH.
  #
  # Buzz downloads its own pinned Node.js from nodejs.org into
  # ~/.local/share/Buzz/runtimes/ and gates its agent-install flow on
  # `node --version` succeeding. It pins an exact patch release and offers no
  # override, so pointing it at a nixpkgs node is not an option — the downloaded
  # binary simply has to be runnable.
  #
  # Widen `libraries` only when a specific binary fails on a named missing .so.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib # libstdc++.so.6, libgcc_s.so.1
      zlib
    ];
  };

  # Buzz's installer hardcodes absolute shell paths — resolve_install_shell()
  # takes /bin/zsh if it exists and otherwise returns /bin/bash, with no PATH
  # lookup and no BUZZ_SHELL override on Unix. NixOS provides only /bin/sh, so
  # the spawn fails with ENOENT ("failed to spawn shell: No such file or
  # directory") before any install command runs.
  #
  # Only /bin/bash is linked: it is the branch Buzz falls through to, and its
  # install commands are written for bash `-l -c`. If more of these turn up,
  # `services.envfs` populates /bin and /usr/bin from PATH wholesale — a bigger
  # hammer than this deliberately is.
  systemd.tmpfiles.rules = [
    "L+ /bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
  ];
}
