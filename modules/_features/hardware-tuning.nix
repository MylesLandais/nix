{
  lib,
  ...
}:
{
  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  # Bluetooth support + GUI manager (tray applet)
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Privacy = "device";
        JustWorksRepairing = "always";
        Class = "0x000100";
        FastConnectable = "true";
      };
    };
  };
  services.blueman.enable = true;

  # Compressed RAM swap - gives the kernel a release valve under memory
  # pressure without touching disk. 128 GB RAM => ~16 GB effective swap.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };

  # VM tuning for interactive desktop responsiveness
  boot.kernel.sysctl = {
    # Prefer zram swap over keeping idle anon pages resident
    "vm.swappiness" = 180;
    # Flush dirty pages sooner — defaults allow 25 GB to accumulate
    "vm.dirty_ratio" = 5;
    "vm.dirty_background_ratio" = 1;
    # Reclaim dentries/inodes more aggressively to free slab memory
    "vm.vfs_cache_pressure" = 150;
    # Watermark boost helps avoid direct reclaim stalls
    "vm.watermark_boost_factor" = 15000;
    "vm.watermark_scale_factor" = 125;
    # Start reclaiming pages sooner
    "vm.min_free_kbytes" = 524288;
    # Reduce page lock contention on multi-core
    "vm.page-cluster" = 0;
  };

  # Prevent USB/input devices from suspending, set NVMe I/O scheduler
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/autosuspend}="0"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/control}="on"
    SUBSYSTEM=="input", ATTR{power/autosuspend}="0"
    SUBSYSTEM=="input", ATTR{power/control}="on"

    # 8BitDo Pro 2 controller — TAG+="uaccess" lets Steam access hidraw
    # without root. Covers both wired/2.4GHz (idVendor) and Bluetooth (KERNELS)
    KERNEL=="hidraw*", ATTRS{idVendor}=="2dc8", MODE="0660", TAG+="uaccess"
    KERNEL=="hidraw*", KERNELS=="*2DC8:*", MODE="0660", TAG+="uaccess"

    # Use kyber I/O scheduler for NVMe — prioritizes latency-sensitive
    # reads over bulk writes so interactive I/O isn't starved
    ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="kyber"
    # 256 KB read-ahead (default 8 MB is far too aggressive for interactive)
    ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/read_ahead_kb}="256"
  '';

  # nvidia-container-toolkit CDI generator workaround
  systemd.services.nvidia-container-toolkit-cdi-generator.serviceConfig.ExecStartPre =
    lib.mkForce null;

  systemd.coredump.settings.Coredump = {
    MaxUse = "512M";
    KeepFree = "1G";
  };
}
