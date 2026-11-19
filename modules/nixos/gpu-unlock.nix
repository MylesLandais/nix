# Zagitta/gpu-unlock 2.0: raises the FP16/BF16/TF32 tensor issue rate on
# Ampere GeForce cards (GA10x) to the professional-card rate. Turing and Ada
# are upstream-experimental; Blackwell is unsupported. The module runs before
# nvidia binds the card: it boots NVIDIA-signed falcon firmware derived from
# the CMP 610.43.03 reference, writes the speed selectors (SS0 0x88888888 for
# the full BF16 rate, SS1 0x8 IMLA4), and FLRs the card. Nothing is flashed;
# a power cycle restores stock. It does nothing unless gpu_unlock.targets= is
# on the kernel command line.
#
# Tracking: the `gpu-unlock` flake input (flake = false; upstream ships no
# flake) follows upstream's default branch, so `nix flake update gpu-unlock`
# advances the source pin. The two NVIDIA firmware inputs below stay
# hash-pinned regardless: upstream itself pins 610.43.03 in
# firmware/fetch_artifacts.py, and the module hard-codes the same version.
#
# Upstream's open stability PRs (#35, #70, #72) were absorbed into main by
# the 2.0 recipe-driven rewrite, so the formerly vendored
# modules/nixos/_patches/gpu-unlock set is gone.
#
# Since 2026-11-18 the DEFAULT boot entry unlocks the 3090 Ti; the stock
# comparison is the previous generation rather than a specialisation. A/B
# protocol and stock baselines: ~/Vault/nix-issues/gpu-unlock-ab.md.
{ inputs, ... }: {
  flake.modules.nixos.gpuUnlock =
    let
      # The input is captured here, at the import-tree wrapper, because the
      # module below evaluates inside the host module system, which does not
      # receive `inputs` (only flake.lib.mkHost's external-caller path does).
      gpuUnlockSrc = inputs.gpu-unlock;
    in
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.hardware.gpuUnlock;
      inherit (config.boot.kernelPackages) kernel;
      nv = "610.43.03";

      # Hashes from upstream firmware/fetch_artifacts.py INPUTS.
      nvidiaSource = pkgs.fetchurl {
        url = "https://download.nvidia.com/XFree86/NVIDIA-kernel-module-source/NVIDIA-kernel-module-source-${nv}.tar.xz";
        hash = "sha256-fhGJI8eiPtw2EU1jJzpG4+BOmvmGlaQiA+esLf6fwdw=";
      };
      # The .run installer is only read, never executed: extract_gsp.py opens
      # its makeself payload as an archive and pulls the GSP ELFs and license.
      nvidiaInstaller = pkgs.fetchurl {
        url = "https://download.nvidia.com/XFree86/Linux-x86_64/${nv}/NVIDIA-Linux-x86_64-${nv}-no-compat32.run";
        hash = "sha256-4IRFHbcwpt8p09dPZVdJxNI248lF99lLUgXoQxj+L5A=";
      };

      # All 16 firmware assets the module declares via MODULE_FIRMWARE
      # (recipes.h). Each supported family requests its own set at runtime;
      # only the requested files load, so installing the full set keeps
      # targets=all correct for any card present.
      firmware = pkgs.stdenvNoCC.mkDerivation {
        pname = "gpu-unlock-firmware";
        version = "2.0.0-${nv}";
        src = gpuUnlockSrc;
        nativeBuildInputs = [
          pkgs.python3
          pkgs.zstd
        ];
        dontStrip = true;
        dontPatchELF = true;
        buildPhase = ''
          runHook preBuild
          mkdir -p nvsrc assets
          tar -xf ${nvidiaSource} -C nvsrc
          python3 firmware/extract_gsp.py ${nvidiaInstaller} assets
          python3 firmware/extract_boot_assets.py nvsrc/NVIDIA-kernel-module-source-${nv} assets
          runHook postBuild
        '';
        installPhase = ''
          runHook preInstall
          install -Dm644 -t $out/lib/firmware/gpu-unlock/${nv} assets/*.bin
          install -Dm644 assets/NVIDIA-LICENSE $out/share/licenses/gpu-unlock-firmware/NVIDIA-LICENSE
          install -Dm644 firmware/NOTICE.md $out/share/licenses/gpu-unlock-firmware/NOTICE.md
          runHook postInstall
        '';
      };

      module = kernel.stdenv.mkDerivation {
        pname = "gpu-unlock";
        version = "2.0.0-${kernel.modDirVersion}";
        src = gpuUnlockSrc;
        nativeBuildInputs = kernel.moduleBuildDependencies;
        hardeningDisable = [ "pic" ];
        # The CachyOS kernel is built with clang/lld; build the module with the
        # same toolchain or modpost rejects it.
        makeFlags = kernel.commonMakeFlags ++ [
          "-C"
          "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
          "M=$(PWD)/kernel/gpu_unlock"
          # Upstream CI builds every distro kernel with warnings as errors.
          "KCFLAGS=-Werror"
        ];
        buildFlags = [ "modules" ];
        # Kbuild signs external modules and emits the certificate consumed by aggregateModules.
        installFlags = [
          "INSTALL_MOD_PATH=$(out)"
          "INSTALL_MOD_DIR=extra"
          "DEPMOD=true"
        ];
        installTargets = [ "modules_install" ];
      };
    in
    {
      options.hardware.gpuUnlock = {
        enable = lib.mkEnableOption "the gpu-unlock FP16/BF16 rate unlock for Ampere GeForce cards";
        targets = lib.mkOption {
          type = lib.types.str;
          default = "all";
          example = "0000:2b:00.0";
          description = "Value for gpu_unlock.targets=: \"all\" or comma-separated PCI addresses.";
        };
        resume = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Also run the unlock again after every suspend/resume, since
            suspend powers the card off and resets it.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        hardware.firmware = [ firmware ];
        # The initrd's module closure copies each module's MODULE_FIRMWARE files
        # (compressed or not), so gpu_unlock's declared assets ride along with it.
        boot = {
          extraModulePackages = [ module ];
          initrd.availableKernelModules = [ "gpu_unlock" ];
          kernelParams = [
            "gpu_unlock.targets=${cfg.targets}"
            "gpu_unlock.resume=${lib.boolToString cfg.resume}"
          ];

          # nvidia, nvidia_drm etc. are in boot.initrd.kernelModules
          # (modules/aspects/hardware/nvidia.nix), loaded by
          # systemd-modules-load; udev coldplug could also bind the card.
          # Finish the unlock before either runs. Module init blocks until every
          # target card is done.
          initrd.systemd.services.gpu-unlock = {
            description = "Unlock Ampere FP16/BF16 rate before nvidia binds the GPU";
            wantedBy = [ "initrd.target" ];
            before = [
              "systemd-modules-load.service"
              "systemd-udevd.service"
              "systemd-udev-trigger.service"
            ];
            unitConfig.DefaultDependencies = false;
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              # The kmod that systemd stage 1 already ships in /bin.
              ExecStart = "${config.boot.initrd.systemd.package.kmod}/bin/modprobe gpu_unlock";
            };
          };
        };
      };
    };
}
