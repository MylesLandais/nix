{
  perSystem =
    { pkgs, ... }:
    let
      bootstrap-lacie-bin = pkgs.writeShellApplication {
        name = "bootstrap-lacie";
        runtimeInputs = with pkgs; [
          util-linux
          git
          nixos-install-tools
          coreutils
          gnused
        ];
        text = ''
          # bootstrap-lacie — run from inside a NixOS live ISO booted off Ventoy.
          # Mounts live_nix + VTOYEFI, generates hardware-config, clones the flake
          # locally, and runs nixos-install --flake .#lacie.

          set -euo pipefail

          FLAKE_REPO="https://github.com/MylesLandais/nix.git"
          FLAKE_BRANCH="dendritic"
          FLAKE_HOST="lacie"
          NO_INSTALL=0

          MNT="/mnt"
          BOOT_MNT="$MNT/boot"
          REPO_PATH="$MNT/etc/nixos/repo"

          usage() {
            cat <<EOF
          Usage: bootstrap-lacie [--branch BRANCH] [--repo URL] [--no-install] [--help]

            --branch BRANCH   Flake branch to clone (default: dendritic).
            --repo URL        Override flake repo URL (default: $FLAKE_REPO).
            --no-install      Mount + generate hw-config + clone only; skip nixos-install.
            --help            Print this message.
          EOF
            exit 0
          }

          while [[ $# -gt 0 ]]; do
            case "$1" in
              --branch)     FLAKE_BRANCH="$2"; shift 2 ;;
              --repo)       FLAKE_REPO="$2"; shift 2 ;;
              --no-install) NO_INSTALL=1; shift ;;
              --help|-h)    usage ;;
              *)  echo "Unknown argument: $1"; usage ;;
            esac
          done

          for label in live_nix VTOYEFI; do
            dev=$(lsblk -o LABEL,PATH | awk -v l="$label" '$1==l {print $2}')
            [[ -n "$dev" ]] || { echo "ERROR: Partition labelled '$label' not found."; exit 1; }
            echo "Found $label -> $dev"
          done

          echo "==> Mounting live_nix -> $MNT"
          if ! mountpoint -q "$MNT"; then
            sudo mount /dev/disk/by-label/live_nix "$MNT"
          fi

          echo "==> Mounting VTOYEFI -> $BOOT_MNT"
          sudo mkdir -p "$BOOT_MNT"
          if ! mountpoint -q "$BOOT_MNT"; then
            sudo mount /dev/disk/by-label/VTOYEFI "$BOOT_MNT"
          fi

          echo "==> Generating hardware-configuration.nix (--no-filesystems)"
          sudo nixos-generate-config --root "$MNT" --no-filesystems

          echo
          echo "Generated hardware-configuration.nix preview:"
          sudo head -40 "$MNT/etc/nixos/hardware-configuration.nix"
          echo

          echo "==> Cloning $FLAKE_REPO (branch: $FLAKE_BRANCH) -> $REPO_PATH"
          sudo mkdir -p "$(dirname "$REPO_PATH")"
          if [[ -d "$REPO_PATH/.git" ]]; then
            echo "   Repo already exists; updating."
            sudo git -C "$REPO_PATH" fetch origin
            sudo git -C "$REPO_PATH" checkout "$FLAKE_BRANCH"
            sudo git -C "$REPO_PATH" pull --ff-only origin "$FLAKE_BRANCH"
          else
            sudo git clone --branch "$FLAKE_BRANCH" "$FLAKE_REPO" "$REPO_PATH"
          fi

          # Wrap the raw nixos-generate-config output as a flake module that
          # declares flake.nixosModules.lacieHardware (matches dendritic style).
          GENERATED="$MNT/etc/nixos/hardware-configuration.nix"
          TARGET="$REPO_PATH/modules/hosts/lacie/hardware-configuration.nix"
          echo "==> Wrapping generated hw-config -> $TARGET"
          sudo tee "$TARGET" >/dev/null <<'WRAPPER_HEADER'
          _: {
            flake.nixosModules.lacieHardware =
              { config, lib, modulesPath, ... }:
          WRAPPER_HEADER
          # Strip the outer `{ ... }: { ... }` wrapper from the generated file
          # and inline its body. Keep imports, kernel modules, hostPlatform —
          # drop fileSystems + swapDevices (managed by nixosModules.imaging).
          sudo sh -c "
            sed -e '1,/^{/d' -e '\$d' \"$GENERATED\" \
              | sed -e '/fileSystems/,/^  };/d' \
                    -e '/swapDevices/,/^  ];/d' \
              >> \"$TARGET\"
            echo '  };' >> \"$TARGET\"
            echo '}'    >> \"$TARGET\"
          "
          echo "==> Wrote wrapper. Review before committing back upstream:"
          sudo head -60 "$TARGET"

          if [[ "$NO_INSTALL" -eq 1 ]]; then
            echo
            echo "--no-install: stopping here. To finish manually:"
            echo "  sudo nixos-install --flake $REPO_PATH#$FLAKE_HOST --root $MNT --no-root-passwd"
            exit 0
          fi

          echo
          echo "==> Running nixos-install --flake $REPO_PATH#$FLAKE_HOST --root $MNT"
          sudo nixos-install \
            --flake "$REPO_PATH#$FLAKE_HOST" \
            --root "$MNT" \
            --no-root-passwd

          cat <<EOF

          ==> Install complete.

          Next steps:
            1. Reboot. F12 -> LaCie -> select NixOS (alongside Ventoy).
            2. Verify greetd auto-login as warby, Hyprland, network.
            3. cd /etc/nixos/repo && git status
               -> commit the generated hardware-configuration.nix and push
                  to dendritic so future rebuilds stay clean.

          Recovery: if NixOS entry fails to boot, F12 -> Ventoy -> NixOS ISO,
          then re-run bootstrap-lacie or inspect /mnt/etc/nixos/repo from there.
          EOF
        '';
      };

      bootstrap-lacie = pkgs.symlinkJoin {
        name = "bootstrap-lacie";
        paths = [ bootstrap-lacie-bin ];
        postBuild = ''
          ln -s bootstrap-lacie $out/bin/nix-install
        '';
      };
    in
    {
      packages.bootstrap-lacie = bootstrap-lacie;
      apps.bootstrap-lacie = {
        type = "app";
        program = "${bootstrap-lacie}/bin/bootstrap-lacie";
      };
    };
}
