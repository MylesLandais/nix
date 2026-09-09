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
          # declares flake.modules.nixos.lacieHardware (matches dendritic style).
          GENERATED="$MNT/etc/nixos/hardware-configuration.nix"
          TARGET="$REPO_PATH/modules/hosts/lacie/hardware-configuration.nix"
          echo "==> Wrapping generated hw-config -> $TARGET"
          sudo tee "$TARGET" >/dev/null <<'WRAPPER_HEADER'
          _: {
            flake.modules.nixos.lacieHardware =
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

      test-usb-qemu = pkgs.writeShellApplication {
        name = "test-usb-qemu";
        runtimeInputs = with pkgs; [
          qemu
          OVMF.fd
          util-linux
          coreutils
          gnugrep
          gnused
          openssh
          nix
        ];
        text = ''
          export OVMF_CODE="${pkgs.OVMF.fd}/FV/OVMF_CODE.fd"
          export OVMF_VARS_SRC="${pkgs.OVMF.fd}/FV/OVMF_VARS.fd"
          ${builtins.readFile ../../scripts/test-usb-qemu.sh}
        '';
      };

      windowsKitQemu = pkgs.runCommand "windows-kit-qemu" { } ''
        mkdir -p $out
        cp ${../../windows-kit/autounattend.xml} $out/autounattend.xml
        cp ${../../windows-kit/quick_fix.ps1} $out/quick_fix.ps1
        cp ${../../windows-kit/gamer_verify.ps1} $out/gamer_verify.ps1
        cp ${../../windows-kit/install_rustdesk.ps1} $out/install_rustdesk.ps1
        cp ${../../windows-kit/install_sunshine.ps1} $out/install_sunshine.ps1
        cp ${../../windows-kit/install_virtio_win.ps1} $out/install_virtio_win.ps1
      '';

      winQemuRuntimeInputs = with pkgs; [
        qemu_full
        OVMFFull
        swtpm
        util-linux
        coreutils
        gnugrep
        gnused
        dosfstools
        mtools
        cdrkit
        socat
        virt-viewer
        nix
        openssh
      ];

      test-windows-qemu = pkgs.writeShellApplication {
        name = "test-windows-qemu";
        runtimeInputs = winQemuRuntimeInputs;
        text = ''
          # .ms variants carry the Microsoft-enrolled Secure Boot keys so the
          # firmware actually verifies the Windows bootloader.
          export OVMF_CODE="${pkgs.OVMFFull.fd}/FV/OVMF_CODE.fd"
          export OVMF_VARS_SRC="${pkgs.OVMFFull.fd}/FV/OVMF_VARS.ms.fd"
          export WINDOWS_KIT_DIR="${windowsKitQemu}"
          ${builtins.readFile ../../scripts/lib/qemu-spice.sh}
          ${builtins.readFile ../../scripts/test-windows-qemu.sh}
        '';
      };

      boot-windows-golden = pkgs.writeShellApplication {
        name = "boot-windows-golden";
        runtimeInputs = winQemuRuntimeInputs;
        text = ''
          GOLDEN="$HOME/win-kit-staging/golden"
          QCOW=$(find "$GOLDEN" -maxdepth 1 -name 'win11-pro-gamer-*.qcow2' -printf '%f\n' 2>/dev/null | sort | tail -1)
          QCOW="${"QCOW:+$GOLDEN/$QCOW"}"
          if [ -z "$QCOW" ]; then
            echo "[boot-windows-golden] no golden qcow2 in $GOLDEN" >&2
            exit 1
          fi
          exec ${test-windows-qemu}/bin/test-windows-qemu \
            --boot-target --target "$QCOW" \
            --payload-dir "$HOME/win-kit-staging" \
            --ovmf-vars-persist "$GOLDEN/ovmf-vars.fd" \
            --tpm-dir "$GOLDEN/swtpm" \
            --user-net --open-spice "$@"
        '';
      };

      seal-windows-golden = pkgs.writeShellApplication {
        name = "seal-windows-golden";
        runtimeInputs = with pkgs; [
          qemu_full
          coreutils
        ];
        text = ''
          export WINDOWS_KIT_DIR="${windowsKitQemu}"
          ${builtins.readFile ../../scripts/seal-windows-golden.sh}
        '';
      };

      rustdesk-windows-qemu = pkgs.writeShellApplication {
        name = "rustdesk-windows-qemu";
        runtimeInputs = with pkgs; [
          openssh
        ];
        # TODO(unsolved): this shells out to a system `rustdesk` that is no longer
        # installed — it was dropped from modules/_packages.nix on 2026-08-09 because
        # the nixpkgs bump forced an uncached Rust+Flutter rebuild that blew the build
        # budget. This wrapper will fail with "rustdesk: command not found" until the
        # package is restored (see the note in modules/_packages.nix).
        text = builtins.readFile ../../scripts/rustdesk-windows-qemu.sh;
      };

      extract-installer-boot = pkgs.writeShellApplication {
        name = "extract-installer-boot";
        runtimeInputs = with pkgs; [
          nix
          coreutils
          findutils
        ];
        text = builtins.readFile ../../scripts/extract-installer-boot.sh;
      };

      recovery-preflight = pkgs.writeShellApplication {
        name = "recovery-preflight";
        runtimeInputs = with pkgs; [
          util-linux
          coreutils
          gnugrep
          udisks2
        ];
        text = builtins.readFile ../../scripts/recovery-preflight.sh;
      };

      recovery-verify = pkgs.writeShellApplication {
        name = "recovery-verify";
        runtimeInputs = with pkgs; [
          openssh
          coreutils
          gnugrep
        ];
        text = builtins.readFile ../../scripts/recovery-verify.sh;
      };

      iso-deploy = pkgs.writeShellApplication {
        name = "iso-deploy";
        runtimeInputs = with pkgs; [
          nix
          coreutils
          util-linux
          git
          gnused
          openssh
        ];
        text = builtins.readFile ../../scripts/iso-deploy.sh;
      };
    in
    {
      packages.bootstrap-lacie = bootstrap-lacie;
      packages.test-usb-qemu = test-usb-qemu;
      packages.test-windows-qemu = test-windows-qemu;
      packages.boot-windows-golden = boot-windows-golden;
      packages.seal-windows-golden = seal-windows-golden;
      packages.rustdesk-windows-qemu = rustdesk-windows-qemu;
      packages.extract-installer-boot = extract-installer-boot;
      packages.recovery-preflight = recovery-preflight;
      packages.recovery-verify = recovery-verify;
      packages.iso-deploy = iso-deploy;
      apps.bootstrap-lacie = {
        type = "app";
        program = "${bootstrap-lacie}/bin/bootstrap-lacie";
      };
      apps.test-usb-qemu = {
        type = "app";
        program = "${test-usb-qemu}/bin/test-usb-qemu";
      };
      apps.test-windows-qemu = {
        type = "app";
        program = "${test-windows-qemu}/bin/test-windows-qemu";
      };
      apps.boot-windows-golden = {
        type = "app";
        program = "${boot-windows-golden}/bin/boot-windows-golden";
      };
      apps.seal-windows-golden = {
        type = "app";
        program = "${seal-windows-golden}/bin/seal-windows-golden";
      };
      apps.rustdesk-windows-qemu = {
        type = "app";
        program = "${rustdesk-windows-qemu}/bin/rustdesk-windows-qemu";
      };
      apps.extract-installer-boot = {
        type = "app";
        program = "${extract-installer-boot}/bin/extract-installer-boot";
      };
      apps.recovery-preflight = {
        type = "app";
        program = "${recovery-preflight}/bin/recovery-preflight";
      };
      apps.recovery-verify = {
        type = "app";
        program = "${recovery-verify}/bin/recovery-verify";
      };
      apps.iso-deploy = {
        type = "app";
        program = "${iso-deploy}/bin/iso-deploy";
      };
    };
}
