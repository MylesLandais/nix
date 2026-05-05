_: {
  flake.nixosModules.lacie =
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
        hostName = "lacie";
        isDesktop = false;
        class = "laptop";
        bar = "noctalia";
        greeter = "greetd";
        gpuType = "none";
        theme = "kanagawa-dragon";
        profile = "default";
        imaging = {
          enable = true;
          mode = "ventoy";
        };
        wallpaper = "${inputs.wallpapers.packages.x86_64-linux.default}/share/wallpapers/kanagawa-dragon/3895e.jpg";
        mainMonitor = {
          name = "eDP-1";
          width = "1920";
          height = "1080";
          refresh = "60";
        };
        secondaryMonitor = {
          name = "HDMI-A-1";
          width = "1920";
          height = "1080";
          refresh = "60";
        };
      };

      networking = {
        hostName = "lacie";
        networkmanager.enable = true;
        wireless.enable = lib.mkDefault false;
      };

      services = {
        tailscale.enable = true;
        openssh = {
          enable = true;
          settings = {
            UseDns = false;
            PasswordAuthentication = false;
            PermitRootLogin = "no";
          };
        };
        pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
          jack.enable = true;
        };
        blueman.enable = true;
        upower.enable = true;
        power-profiles-daemon.enable = true;
        gnome.gnome-keyring.enable = true;
        xserver = {
          enable = true;
          xkb = {
            layout = "us";
            variant = "";
          };
        };
      };

      hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
      };

      programs = {
        zsh.enable = true;
        hyprland = {
          enable = true;
          xwayland.enable = true;
        };
      };

      security = {
        rtkit.enable = true;
        sudo.wheelNeedsPassword = false;
        pam.services.greetd.enableGnomeKeyring = true;
      };

      time.timeZone = "America/Chicago";
      i18n.defaultLocale = "en_US.UTF-8";

      fonts.packages = [
        pkgs.nerd-fonts.hack
        pkgs.maple-mono.NF-unhinted
        pkgs.maple-mono.truetype
        pkgs.noto-fonts-cjk-sans
      ];

      users = {
        defaultUserShell = pkgs.fish;
        # mutableUsers stays at default true here; portable USB needs simple recovery.
        users.warby = {
          isNormalUser = true;
          description = "warby";
          extraGroups = [
            "wheel"
            "networkmanager"
            "audio"
            "video"
            "bluetooth"
          ];
          # Empty hashedPassword = passwordless console login. Deliberate for the
          # single-user portable USB threat model (auto-login + wheel NOPASSWD).
          # SSH still requires keys (PasswordAuthentication = false above).
          hashedPassword = "";
        };
      };

      environment.systemPackages = with pkgs; [
        git
        vim
        tmux
        wget
        curl
        ripgrep
        fd
        htop
        pciutils
        usbutils
        tailscale
      ];

      system.stateVersion = "25.11";
    };
}
