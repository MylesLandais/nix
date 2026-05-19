_: {
  flake.nixosModules.tl0m2 =
    { config, lib, pkgs, inputs, ... }:
    {
      imports = [ "${inputs.self}/modules/features/ssh-keys.nix" ];

      nixpkgs.config.allowUnfree = true;

      networking.hostName = "94tl0m2";

      boot = {
        loader = {
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
        };
        kernelParams = [
          "quiet"
          "loglevel=3"
        ];
      };

      networking = {
        useDHCP = true;
        firewall = {
          enable = true;
          allowedTCPPorts = [
            22
          ];
        };
      };

      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
          UseDns = false;
        };
      };

      services.tailscale.enable = true;

      time.timeZone = "America/New_York";
      i18n.defaultLocale = "en_US.UTF-8";

      virtualisation.docker = {
        enable = true;
        enableOnBoot = true;
      };

      services.journald.extraConfig = ''
        SystemMaxUse=500M
        MaxFileSec=7day
      '';

      users = {
        defaultUserShell = pkgs.fish;
        users.warby = {
          isNormalUser = true;
          description = "warby";
          extraGroups = [
            "wheel"
            "docker"
            "video"
            "render"
            "disk"
          ];
          hashedPassword = "";
        };
      };

      security.sudo.wheelNeedsPassword = false;

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
        docker-compose
        tailscale
      ];

      programs.fish.enable = true;

      nix.settings.trusted-users = [ "root" "warby" "@wheel" ];

      system.stateVersion = "25.11";
    };
}
