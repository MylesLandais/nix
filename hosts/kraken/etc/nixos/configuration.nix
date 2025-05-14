# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  config,
  lib,
  pkgs,
  inputs,
  extra-types,
  ...
}:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./ollama.nix
    ./udev.nix
    #<home-manager/nixos>
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    "pci=nomsi"
    "clearcpuid=514"
    "nvidia_drm.fbdev=1"
  ];

  # network config

  networking.hostName = "kraken"; # Define your hostname.
  networking.search = [ "universe.home" ];
  networking.nameservers = [
    "192.168.0.2"
    "192.168.0.1"
  ];
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  #nix.nixPath = ["nixpkgs=${nixpkgs}"];
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "Europe/Madrid";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  services.opentelemetry-collector = {
    enable = true;
    package = pkgs.opentelemetry-collector-contrib;
    settings = {
      receivers = {
        hostmetrics = {
          collection_interval = "60s";
          scrapers = {
            cpu = { };
            disk = { };
            load = { };
            filesystem = { };
            memory = { };
            network = { };
          };
        };
      };
      processors = {
        resourcedetection = {
          detectors = [
            "env"
            "system"
          ];
          system = {
            hostname_sources = "os";
          };
        };
      };
      extensions = {
        zpages = { };
        health_check = { };
      };
      exporters = {
        otlphttp = {
          endpoint = "https://otelcollector.universe.home:443";
          tls = {
            insecure = false;
            insecure_skip_verify = true;
          };
        };
      };
      service = {
        telemetry = {
          metrics = {
            address = "0.0.0.0:8888";
          };
        };
        extensions = [
          "zpages"
          "health_check"
        ];
        pipelines = {
          "metrics/hostmetrics" = {
            receivers = [ "hostmetrics" ];
            processors = [ "resourcedetection" ];
            exporters = [ "otlphttp" ];
          };
        };
      };
    };
  };
  services.prometheus = {
    exporters = {
      node = {
        enable = true;
        openFirewall = true;
        enabledCollectors = [
          "systemd"
          "logind"
        ];
      };
      nvidia-gpu = {
        enable = true;
        openFirewall = true;
      };
    };
  };
  services.promtail = {
    enable = true;
    configuration = {
      server = {
        http_listen_port = 3101;
        grpc_listen_port = 0;
      };
      positions = {
        filename = "/tmp/positions.yaml";
      };
      clients = [
        {
          url = "https://loki.pik8s.universe.home/loki/api/v1/push";
          tls_config = {
            insecure_skip_verify = true;
          };
        }
      ];
      scrape_configs = [
        {
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels = {
              job = "systemd-journal";
              host = "kraken";
            };
          };
          relabel_configs = [
            {
              source_labels = [ "__journal__systemd_unit" ];
              target_label = "unit";
            }
          ];
        }
      ];
    };
  };
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };
  services.rpcbind.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      mesa
      nvidia-vaapi-driver
    ];
    enable32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
  };

  virtualisation.docker.enable = true;
  virtualisation.libvirtd.enable = true;
  services.xserver.enable = true;
  services.blueman.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    sugarCandyNix = {
      enable = true;
      settings = {
        Background = lib.cleanSource ./wp2.jpg;
        ScreenWidth = 1920;
        ScreenHeight = 1080;
        FormPosition = "left";
        HaveFormBackground = true;
        PartialBlur = true;
      };
    };
  };
  programs.zsh.enable = true;
  programs.fish.enable = true;
  programs.nh.enable = true;
  programs.firefox.enable = true;
  programs.steam.enable = true;
  programs.hyprland.enable = true;
  programs.hyprland.xwayland.enable = true;

  security.rtkit.enable = true;
  fonts.packages = with pkgs; [
    nerd-fonts.hack
  ];
  users.defaultUserShell = pkgs.fish;
  users.motd = ''

              ▗▄▄▄       ▗▄▄▄▄    ▄▄▄▖
              ▜███▙       ▜███▙  ▟███▛
               ▜███▙       ▜███▙▟███▛
                ▜███▙       ▜██████▛
         ▟█████████████████▙ ▜████▛     ▟▙
        ▟███████████████████▙ ▜███▙    ▟██▙
               ▄▄▄▄▖           ▜███▙  ▟███▛
              ▟███▛             ▜██▛ ▟███▛
             ▟███▛               ▜▛ ▟███▛
    ▟███████████▛                  ▟██████████▙
    ▜██████████▛                  ▟███████████▛
          ▟███▛ ▟▙               ▟███▛
         ▟███▛ ▟██▙             ▟███▛
        ▟███▛  ▜███▙           ▝▀▀▀▀
        ▜██▛    ▜███▙ ▜██████████████████▛
         ▜▛     ▟████▙ ▜████████████████▛
               ▟██████▙       ▜███▙
              ▟███▛▜███▙       ▜███▙
             ▟███▛  ▜███▙       ▜███▙
             ▝▀▀▀    ▀▀▀▀▘       ▀▀▀▘
             welcome!
  '';
  users.users.franky = {
    isNormalUser = true;
    description = "franky";
    extraGroups = [
      "networkmanager"
      "qemu-libvirtd"
      "libvirtd"
      "audio"
      "disk"
      "wheel"
      "docker"
    ];
    packages = with pkgs; [
      nixfmt-rfc-style
      nixd
      openssl
      openssl.dev
      qemu
      qemu_kvm
      nfs-utils
      nvtopPackages.nvidia
    ];
  };
  nix.optimise.automatic = true;
  nix.settings.trusted-users = [
    "root"
    "franky"
    "@wheel"
  ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  system.stateVersion = "24.11"; # Did you read the comment?
}
