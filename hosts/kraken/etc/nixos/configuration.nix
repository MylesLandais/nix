# Edit this configuration file to define what should be installed onhosts
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  config,
  lib,
  pkgs,
  inputs,
  extra-types,
  vars,
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
    ./glance.nix
    ./udev.nix
    ./logiops.nix
    #<home-manager/nixos>
  ];

  nix = {
    settings = {
      substituters = [
        "https://nix-community.cachix.org/"
        "https://attic.xuyh0120.win/lantian"
        "https://cache.nixos.org/"
        "https://zed.cachix.org/"
        "https://cache.garnix.io/"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
        "zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU="
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      ];

      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        "franky"
        "@wheel"
      ];
    };

    optimise.automatic = true;

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 3d";
    };
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    plymouth.enable = true;
    kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;
    kernelParams = [
      "pci=nomsi"
      "acpi_enforce_reosurces=lax"
      "clearcpuid=514"
    ];
  };

  # network config

  systemd.packages = with pkgs; [ lact ];
  systemd.services = {
    dhcpd.enable = false;
    lactd.wantedBy = [ "multi-user.target" ];
  };
  networking = {
    firewall = {
      allowedTCPPorts = [
        22
        10767
      ];
    };
    useDHCP = false;
    hostName = "kraken"; # Define your hostname.
    search = [ "universe.home" ];
    nameservers = [
      "192.168.0.2"
      "192.168.0.1"
    ];
    interfaces.enp10s0 = {
      ipv4.addresses = [
        {
          address = "192.168.0.38";
          prefixLength = 24;
        }
      ];
    };
    defaultGateway = {
      address = "192.168.0.1";
      interface = "enp10s0";
    };
    networkmanager = {
      enable = false;
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
    journald.extraConfig = "SystemMaxUse=50M";
    pulseaudio.enable = false;
    hardware.openrgb = {
      enable = true;
      motherboard = "amd";
    };

    greetd = {
      enable = true;
      settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --xsessions ${config.services.displayManager.sessionData.desktops}/share/xsessions --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions --remember --remember-user-session --user-menu --user-menu-min-uid 1000 --asterisks --power-shutdown 'shutdown -P now' --power-reboot 'shutdown -r now'";
    };

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
      extraConfig = {
        pipewire = {
          "10-custom-latency.conf" = {
            "context.properties" = {
              "default.clock.min-quantum" = 256;
              "default.clock.quantum" = 1024;
              "api.alsa.headroom" = 1024;
            };
          };
          "99-pcm2900c-loopback.conf" = {
            "context.modules" = [
              {
                name = "libpipewire-module-loopback";
                args = {
                  "node.name" = "pcm2900c-loopback";
                  "node.description" = "PCM2900C Loopback";
                  "auto.connect" = true;
                  "capture.props" = {
                    "node.target" = "alsa_input.usb-BurrBrown_from_Texas_Instruments_USB_AUDIO_CODEC-00.pro-input-0";
                    "media.class" = "Audio/Source";
                  };
                  "playback.props" = {
                    "node.passive" = true;
                    "media.class" = "Audio/Sink";
                  };
                };
              }
            ];
          };
        };
        pipewire-pulse = {
          "10-custom-latency.conf" = {
            "context.properties" = {
              "default.clock.min-quantum" = 256;
              "default.clock.quantum" = 1024;
            };
          };
        };
      };

      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    displayManager = {
      sddm = {
        enable = false;
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
  };

  hardware = {
    logitech.wireless.enable = true;
    logitech.wireless.enableGraphical = true;
    amdgpu = {
      overdrive.enable = true;
      opencl.enable = true;
      initrd.enable = true;
    };

    graphics = {
      enable = true;
      enable32Bit = true;
    };

  };
  virtualisation = {
    docker = {
      enable = true;
    };
    libvirtd.enable = true;
  };
  programs = {
    gpu-screen-recorder.enable = true;
    zsh.enable = true;
    fish.enable = true;
    nh.enable = true;
    firefox.enable = true;
    steam.enable = true;
    hyprland.enable = true;
    hyprland.xwayland.enable = true;
  };

  security = {
    rtkit.enable = true;
    pam.services.gdm.enableGnomeKeyring = true;
  };
  fonts.packages = with pkgs; [
    nerd-fonts.hack
  ];
  environment.systemPackages = with pkgs; [
    lact
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
        wireguard-tools
        kdePackages.qtmultimedia
      ];
    };
  };
  system.stateVersion = "24.11"; # Did you read the comment?
}
