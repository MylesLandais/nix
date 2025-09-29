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
let
  sddm-astronaut = pkgs.sddm-astronaut.override (oldAttrs: {
    embeddedTheme = "japanese_aesthetic";
  });
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./ollama.nix
    ./udev.nix
    ./logiops.nix
    #<home-manager/nixos>
  ];

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    optimise.automatic = true;

    settings.trusted-users = [
      "root"
      "franky"
      "@wheel"
    ];

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_cachyos;
    kernelParams = [
      "pci=nomsi"
      "clearcpuid=514"
      "nvidia_drm.fbdev=1"
    ];
  };

  # network config

  networking = {
    hostName = "kraken"; # Define your hostname.
    search = [ "universe.home" ];
    nameservers = [
      "192.168.0.2"
      "192.168.0.1"
    ];
    networkmanager = {
      plugins = with pkgs; [
        networkmanager-openvpn
      ];
    };
  };
  #nix.nixPath = ["nixpkgs=${nixpkgs}"];

  # Set your time zone.
  time.timeZone = "Europe/Madrid";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  services = {
    pulseaudio.enable = false;
    openssh = {
      enable = true;
      ports = [ 22 ];
      settings = {
        PasswordAuthentication = true;
        UseDns = false;
        X11Forwarding = false;

      };
    };
    opentelemetry-collector = {
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
    prometheus = {
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
    promtail = {
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
    tailscale = {
      enable = true;
      useRoutingFeatures = "client";
    };
    rpcbind.enable = true;
    xserver.videoDrivers = [ "nvidia" ];
    xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "";
      };
    };
    blueman.enable = true;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      theme = lib.mkForce "sddm-astronaut-theme";
      extraPackages = with pkgs; [
        sddm-astronaut
      ];
      settings = {
        Theme = {
          Current = "sddm-astronaut-theme";
        };
      };
    };
  };
  hardware = {
    nvidia-container-toolkit.enable = true;
    logitech.wireless.enable = true;
    logitech.wireless.enableGraphical = true;
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        mesa
        nvidia-vaapi-driver
      ];
      enable32Bit = true;
    };

    nvidia = {
      modesetting.enable = true;
      open = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.beta;
    };

  };
  virtualisation = {
    docker = {
      enable = true;
    };
    libvirtd.enable = true;
  };
  programs = {
    zsh.enable = true;
    fish.enable = true;
    nh.enable = true;
    firefox.enable = true;
    steam.enable = true;
    hyprland.enable = true;
    hyprland.xwayland.enable = true;
  };

  security.rtkit.enable = true;
  fonts.packages = with pkgs; [
    nerd-fonts.hack
  ];
  environment.systemPackages = with pkgs; [
    sddm-astronaut
  ];
  users = {
    defaultUserShell = pkgs.fish;
    motd = ''

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
    users.franky = {
      isNormalUser = true;
      description = "franky";
      extraGroups = [
        "networkmanager"
        "qemu-libvirtd"
        "libvirtd"
        "dialout"
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
        wireguard-tools
        kdePackages.qtmultimedia
      ];
    };
  };
  system.stateVersion = "24.11"; # Did you read the comment?
}
