_: {
  flake.nixosModules.kaliVm =
    {
      config,
      lib,
      pkgs,
      inputs,
      ...
    }:
    {
      nixpkgs.config.allowUnfree = true;

      host = {
        hostName = "kali-vm";
        isDesktop = true;
        class = "desktop";
        bar = "noctalia";
        desktop = "xfce";
      kali.enable = true;
        kali.profile = "large";
        greeter = "greetd";
        gpuType = "none";
        theme = "kanagawa-dragon";
        profile = "default";
        wallpaper = "${inputs.wallpapers.packages.x86_64-linux.default}/share/wallpapers/kanagawa-dragon/3895e.jpg";
        mainMonitor = {
          name = "Virtual-1";
          width = "1920";
          height = "1080";
          refresh = "60";
        };
        secondaryMonitor = {
          name = "Virtual-2";
          width = "1920";
          height = "1080";
          refresh = "60";
        };
      };

      networking = {
        hostName = "kali-vm";
        networkmanager.enable = true;
        firewall.enable = false;
      };

      time.timeZone = "America/Chicago";

      users.users.kali = {
        isNormalUser = true;
        description = "Kali";
        extraGroups = [
          "wheel"
          "networkmanager"
          "video"
          "audio"
        ];
        initialPassword = "kali";
        shell = pkgs.fish;
      };

      services.getty.autologinUser = lib.mkDefault "kali";

      security.sudo.wheelNeedsPassword = false;

      virtualisation.vmVariant = {
        virtualisation = {
          memorySize = 4096;
          cores = 4;
          diskSize = 16384;
          graphics = true;
          qemu.options = [
            "-vga virtio"
            "-display gtk,gl=on"
          ];
          forwardPorts = [
            {
              from = "host";
              host.port = 2222;
              guest.port = 22;
            }
          ];
        };
      };

      services.openssh.enable = true;

      system.stateVersion = "24.11";
    };
}
