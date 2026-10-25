# Zagitta/gpu-unlock: raises the FP16/BF16 tensor issue rate on Ampere
# GeForce cards (GA102/3/4/6) to the pro-card rate. The module runs before
# nvidia binds the card: it boots NVIDIA-signed falcon firmware derived from
# the CMP 610.43.03 reference, writes the speed selectors, and FLRs the card.
# Nothing is flashed; a power cycle restores stock. It does nothing unless
# gpu_unlock.targets= is on the kernel command line.
#
# Cerberus only enables this in the gpu-unlock / gpu-unlock-patched boot
# specialisations, so the default entry stays stock. A/B protocol and results:
# ~/Vault/nix-issues/gpu-unlock-ab.md.
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

  upstream = pkgs.fetchFromGitHub {
    owner = "Zagitta";
    repo = "gpu-unlock";
    rev = "af28cbbfd3d922a659227ecfb7369adfd924cf03";
    hash = "sha256-6FaDuPojB707ds7gkQY/g/+m4Tnz1xHZ95UjNfFxBJc=";
  };

  # Open upstream PRs, vendored from their head commits: #35 (fb457b1f) FWSEC
  # DMEM DMA rounding + pre-launch geometry check, #70 (52482230) wait for GFW
  # on a cold card, #72 (1cb357f6) keep polling on PRI-error samples.
  stabilityPatches = [
    ./patches/gpu-unlock/0001-pr35-fwsec-dmem-dma-rounding.patch
    ./patches/gpu-unlock/0002-pr70-wait-gfw-cold-card.patch
    ./patches/gpu-unlock/0003-pr72-gfw-pri-error-polling.patch
  ];

  src = pkgs.applyPatches {
    name = "gpu-unlock-src${lib.optionalString cfg.patched "-patched"}";
    src = upstream;
    patches = lib.optionals cfg.patched stabilityPatches;
  };

  # Hashes from upstream firmware/artifacts-610.43.03.json.
  nvidiaSource = pkgs.fetchurl {
    url = "https://download.nvidia.com/XFree86/NVIDIA-kernel-module-source/NVIDIA-kernel-module-source-${nv}.tar.xz";
    sha256 = "7e118923c7a23edc36114d63273a46e3e04e9af98695a42203e7ac2dfe9fc1dc";
  };
  nvidiaUtils = pkgs.fetchurl {
    url = "https://archive.cachyos.org/archive/cachyos-v3/nvidia-utils-${nv}-1-x86_64_v3.pkg.tar.zst";
    sha256 = "e17e7c92eeffa178b0fe1f40eb17a47095f8fc3ce4a77bf115cf5bd5a4df86e9";
  };

  # The five files the module loads from gpu-unlock/610.43.03/. Both
  # generators check every input and output against a pinned SHA-256, so this
  # is identical whether or not the stability patches are applied.
  firmware = pkgs.stdenvNoCC.mkDerivation {
    pname = "gpu-unlock-firmware";
    version = "1.0.0-${nv}";
    src = upstream;
    # Python 3.14+ for zstd tarfile support.
    nativeBuildInputs = [
      pkgs.python314
      pkgs.zstd
    ];
    dontStrip = true;
    dontPatchELF = true;
    buildPhase = ''
      runHook preBuild
      mkdir -p nvsrc assets
      tar -xf ${nvidiaSource} -C nvsrc
      python3 firmware/generate_v67.py ${nvidiaUtils} assets
      python3 firmware/extract_boot_assets.py nvsrc/NVIDIA-kernel-module-source-${nv} assets
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm644 -t $out/lib/firmware/gpu-unlock/${nv} \
        assets/booter_load_ga102.bin assets/gsp_ga10x.bin assets/gsp_boot_ga102.bin \
        assets/gsp_boot_desc_ga102.bin assets/v67-ga102-${nv}.bin
      install -Dm644 assets/NVIDIA-LICENSE $out/share/licenses/gpu-unlock-firmware/NVIDIA-LICENSE
      install -Dm644 firmware/NOTICE.md $out/share/licenses/gpu-unlock-firmware/NOTICE.md
      runHook postInstall
    '';
  };

  module = kernel.stdenv.mkDerivation {
    pname = "gpu-unlock";
    version = "1.0.0-${kernel.modDirVersion}${lib.optionalString cfg.patched "-patched"}";
    inherit src;
    nativeBuildInputs = kernel.moduleBuildDependencies ++ [ pkgs.python314 ];
    hardeningDisable = [ "pic" ];
    # The CachyOS kernel is built with clang/lld; build the module with the
    # same toolchain or modpost rejects it.
    makeFlags = kernel.commonMakeFlags ++ [
      "-C"
      "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      "M=$(PWD)/kernel/gpu_unlock"
    ];
    buildFlags = [ "modules" ];
    # Upstream's suite: C unit tests under kernel shims, plus the whole unlock
    # against mocked hardware with the real firmware. Runs with the patches,
    # so their added test cases run too.
    doCheck = true;
    checkPhase = ''
      runHook preCheck
      GPU_UNLOCK_ASSETS=${firmware}/lib/firmware/gpu-unlock/${nv} CC=${pkgs.stdenv.cc}/bin/cc \
        python3 -m unittest discover -s tests -v
      runHook postCheck
    '';
    installPhase = ''
      runHook preInstall
      install -Dm644 kernel/gpu_unlock/gpu_unlock.ko \
        $out/lib/modules/${kernel.modDirVersion}/extra/gpu_unlock.ko
      runHook postInstall
    '';
  };
in
{
  options.hardware.gpuUnlock = {
    enable = lib.mkEnableOption "the gpu-unlock FP16/BF16 rate unlock for Ampere GeForce cards";
    patched = lib.mkEnableOption "the open upstream stability PRs (#35, #70, #72)";
    targets = lib.mkOption {
      type = lib.types.str;
      default = "all";
      example = "0000:2b:00.0";
      description = "Value for gpu_unlock.targets=: \"all\" or comma-separated PCI addresses.";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.firmware = [ firmware ];
    # The initrd's module closure copies each module's MODULE_FIRMWARE files
    # (compressed or not), so gpu_unlock's five files ride along with it.
    boot = {
      extraModulePackages = [ module ];
      initrd.availableKernelModules = [ "gpu_unlock" ];
      kernelParams = [ "gpu_unlock.targets=${cfg.targets}" ];

      # nvidia, nvidia_drm etc. are in boot.initrd.kernelModules (_nvidia.nix),
      # loaded by systemd-modules-load; udev coldplug could also bind the card.
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
}
