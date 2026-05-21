_: {
  flake.nixosModules.argus =
    { config, lib, pkgs, inputs, ... }:
    {
      imports = [ "${inputs.self}/modules/features/ssh-keys.nix" ];

      nixpkgs.config.allowUnfree = true;

      # ---------------------------------------------------------------------------
      # Host identity
      # ---------------------------------------------------------------------------
      networking.hostName = "argus";

      # ---------------------------------------------------------------------------
      # Boot
      # ---------------------------------------------------------------------------
      boot = {
        loader = {
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
        };
        supportedFilesystems = [ "ntfs" "exfat" ];
        kernelParams = [
          # Quiet boot for a headless box, but keep early messages.
          "quiet"
          "loglevel=3"
        ];
      };

      # ---------------------------------------------------------------------------
      # NVIDIA (Quadro K2200 — Maxwell GM107)
      # ---------------------------------------------------------------------------
      # The K2200 needs the proprietary driver. Open kernel modules do NOT support
      # Maxwell. If production/stable drops Maxwell in a future nixpkgs revision,
      # fall back to: config.boot.kernelPackages.nvidiaPackages.legacy_470
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.nvidia = {
        package = config.boot.kernelPackages.nvidiaPackages.production;
        modesetting.enable = true;
        open = lib.mkForce false;
      };

      # Container GPU passthrough for CUDA inference in Docker (WD14/CLIP/etc).
      hardware.nvidia-container-toolkit.enable = true;

      # ---------------------------------------------------------------------------
      # Networking
      # ---------------------------------------------------------------------------
      networking = {
        useDHCP = true;
        firewall = {
          enable = true;
          allowedTCPPorts = [
            22    # SSH
            8081  # booru (placeholder — adjust when you move the service)
            8333  # SeaweedFS S3
            9333  # SeaweedFS master
          ];
        };
      };

      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          UseDns = false;
        };
      };

      services.tailscale.enable = true;

      # ---------------------------------------------------------------------------
      # Locale / Time
      # ---------------------------------------------------------------------------
      time.timeZone = "America/Chicago";
      i18n.defaultLocale = "en_US.UTF-8";

      # ---------------------------------------------------------------------------
      # Virtualisation (Docker for booru/SeaweedFS stack)
      # ---------------------------------------------------------------------------
      virtualisation.docker = {
        enable = true;
        storageDriver = "btrfs";  # change to "overlay2" if root fs is ext4
        enableOnBoot = true;
      };

      # ---------------------------------------------------------------------------
      # Services — headless, no audio/X11/desktop
      # ---------------------------------------------------------------------------
      services.journald.extraConfig = ''
        SystemMaxUse=500M
        MaxFileSec=7day
      '';

      # ---------------------------------------------------------------------------
      # Users
      # ---------------------------------------------------------------------------
      users = {
        defaultUserShell = pkgs.fish;
        users.warby = {
          isNormalUser = true;
          description = "warby";
          extraGroups = [
            "wheel"
            "docker"
            "video"      # for NVIDIA device access
            "render"
            "disk"
          ];
          # Set a hashedPassword or use agenix for secrets. Empty = locked.
          hashedPassword = "";
        };
      };

      security.sudo.wheelNeedsPassword = false;

      # ---------------------------------------------------------------------------
      # Packages
      # ---------------------------------------------------------------------------
      environment.systemPackages = with pkgs; [
        git
        vim
        wget
        curl
        htop
        btop
        tmux
        ripgrep
        fd
        pciutils
        usbutils
        smartmontools
        nvtopPackages.full   # GPU monitoring
        docker-compose
        tailscale
      ];

      programs.fish.enable = true;

      # ---------------------------------------------------------------------------
      # Nix settings (override per-host trusted-users from nix-config.nix)
      # ---------------------------------------------------------------------------
      nix.settings.trusted-users = [ "root" "warby" "@wheel" ];

      system.stateVersion = "25.05";
    };
}
