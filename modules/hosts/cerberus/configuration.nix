_: {
  flake.nixosModules.cerberus =
    {
      inputs,
      lib,
      pkgs,
      ...
    }:
    let
      chromiumBrowsers = import "${inputs.self}/modules/_chromium-browsers.nix" { inherit lib; };
      inherit (chromiumBrowsers)
        chromiumStandardExtensions
        heliumBundledExtensionsToRemove
        ;
    in
    {
      imports = [
        inputs.self.nixosModules.cerberusHardware
        "${inputs.self}/modules/_features/ssh-keys.nix"
        inputs.self.nixosModules.nvidia
        inputs.self.nixosModules.gaming
        inputs.self.nixosModules.dev
        inputs.self.nixosModules.agenixHost
        inputs.self.nixosModules.hermes
        inputs.self.nixosModules.chromiumPolicy
        "${inputs.self}/modules/_features/audio.nix"
        "${inputs.self}/modules/_features/sunshine.nix"
        "${inputs.self}/modules/_features/file-sharing.nix"
        "${inputs.self}/modules/_features/syncthing.nix"
        "${inputs.self}/modules/_features/hardware-tuning.nix"
        "${inputs.self}/modules/_features/nix-ld.nix"
        "${inputs.self}/modules/_features/security.nix"
        "${inputs.self}/modules/_features/users.nix"
        "${inputs.self}/modules/_features/firefox-policy.nix"
        inputs.agenix.nixosModules.default
        inputs.self.nixosModules.infraContract
        inputs.self.nixosModules.infraSecrets
        inputs.self.nixosModules.infraIngress
        inputs.self.nixosModules.profileInfraSpine
        inputs.self.nixosModules.profileDemoCerberus
        inputs.self.nixosModules.postgresInfra
        inputs.self.nixosModules.valkeyInfra
        inputs.self.nixosModules.openbaoInfra
        inputs.self.nixosModules.traefikInfra
        inputs.self.nixosModules.authentikInfra
        inputs.self.nixosModules.pyloadInfra
        inputs.self.nixosModules.mayaWorkerInfra
        inputs.self.nixosModules.agenixInfra
      ];

      nixpkgs.overlays = [
        inputs.nix-cachyos-kernel.overlays.pinned
        (import "${inputs.self}/modules/_features/overlays/cursor.nix")
        (_final: prev: {
          # oci-cli 3.88.0 declares setuptools <81, but nixpkgs supplies 82.
          # The wheel builds successfully; only the metadata check is stale.
          oci-cli = prev.oci-cli.overridePythonAttrs (_old: {
            dontCheckRuntimeDeps = true;
          });
        })
      ];

      host = {
        hostName = "cerberus-nix";
        isDesktop = true;
        class = "desktop";
        bar = "noctalia";
        desktop = "hyprland";
        greeter = "sddm";
        gpuType = "nvidia";
        theme = "kanagawa-dragon";
        workload = "default";
        gamehacking.enable = true;
        scbw.enable = true;
        remoteGaming.enable = true;
        syncthing.enable = true;
        wallpaper = "${inputs.wallpapers.packages.x86_64-linux.default}/share/wallpapers/kanagawa-dragon/3895e.jpg";
        mainMonitor = {
          name = "desc:Dell Inc. Dell S2716DG #ASPYT+r5vCzd";
          width = "2560";
          height = "1440";
          refresh = "144";
        };
        secondaryMonitor = {
          name = "desc:Dell Inc. DELL P2422H 46Z5YB3";
          width = "1920";
          height = "1080";
          refresh = "60";
        };
      };

      # TODO(unsolved): the demo spine (Postgres, Valkey, OpenBao, Traefik, Authentik
      # + pyLoad + mayaWorker) collides with the Docker dev stack this workstation
      # already runs, so every spine service lost its port and retried forever:
      # valkey 22474 restarts (:6379 held by a Docker valkey), pyload 9741 (missing
      # /srv/config, re-pulling its image each attempt), authentik x3 at 1162 each
      # (Postgres role auth), maya-bot 11534. Turning the flag off is the fix until
      # the shared-developer services are settled — see docs/infra/README.md.
      # To re-enable: one Postgres and one Valkey must own :5432/:6379 with no Docker
      # container publishing them, and Authentik needs a real key via agenix (its
      # current one is literally "demo-...-replace-with-agenix-before-prod").
      infra.demo.enable = false;

      # Developer Lamia Browser Adapter. Nixpkgs Chromium resolves native hosts
      # through this system registry rather than Chrome's per-user registry.
      environment.etc."chromium/native-messaging-hosts/org.lamia.browser.json".text = builtins.toJSON {
        name = "org.lamia.browser";
        description = "Lamia Browser Adapter development host";
        path = "/home/warby/Workspace-git/maya-unified/scripts/lamia-browser-host-dev.sh";
        type = "stdio";
        allowed_origins = [ "chrome-extension://mlpcnheempoikdefoabobmilgdnicdlm/" ];
      };

      # Chromium-based browser policies (Helium, Chromium, etc.)
      # flags.vaapi here is metadata only; launch flags come from HM *-flags.conf
      # with vaapiMode = "nvidia" (see modules/home.nix + gpuType in cerberus HM).
      chromiumPolicies = {
        enable = true;
        browsers = {
          helium = {
            enable = true;
            # Helium AppImage sandbox maps /etc/chromium into the bwrap container
            # so policies must go through the chromium path for the sandbox.
            policyPath = "chromium";
            extensionUpdateUrl = "https://services.helium.imput.net/ext";
            extensions = chromiumStandardExtensions;
            removedExtensions = heliumBundledExtensionsToRemove;
            flags = {
              verticalTabs = true;
              vaapi = true;
              wayland = true;
            };
          };
          vivaldi = {
            enable = true;
            policyPath = "opt/vivaldi";
            extensions = chromiumStandardExtensions;
            flags = {
              verticalTabs = true;
              vaapi = true;
              wayland = true;
            };
          };
        };
      };

      nix.settings.trusted-users = [
        "root"
        "warby"
        "@wheel"
      ];

      boot = {
        plymouth.enable = true;
        consoleLogLevel = 3;
        initrd.verbose = false;
        loader = {
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
        };
        kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;
        kernelParams = [
          "usbcore.autosuspend=-1"
          "quiet"
          "udev.log_level=3"
          "systemd.show_status=auto"
        ];
      };

      time.timeZone = "America/Chicago";
      i18n.defaultLocale = "en_US.UTF-8";
      i18n.extraLocaleSettings = {
        LC_ADDRESS = "en_US.UTF-8";
        LC_IDENTIFICATION = "en_US.UTF-8";
        LC_MEASUREMENT = "en_US.UTF-8";
        LC_MONETARY = "en_US.UTF-8";
        LC_NAME = "en_US.UTF-8";
        LC_NUMERIC = "en_US.UTF-8";
        LC_PAPER = "en_US.UTF-8";
        LC_TELEPHONE = "en_US.UTF-8";
        LC_TIME = "en_US.UTF-8";
      };

      networking.networkmanager = {
        enable = true;
        plugins = with pkgs; [ networkmanager-openvpn ];
      };

      services.tailscale.enable = true;

      services.adguardhome = {
        enable = true;
        openFirewall = true;
        port = 8080;
        settings = {
          dns = {
            bind_host = "0.0.0.0";
            port = 53;
            upstream_dns = [
              "https://dns.quad9.net/dns-query"
              "tls://dns.quad9.net"
            ];
            bootstrap_dns = [
              "9.9.9.9"
              "149.112.112.112"
            ];
            ratelimit = 30;
            cache_size = 8388608;
          };
          filtering = {
            enabled = true;
          };
        };
      };

      services.openssh = {
        enable = true;
        settings.PasswordAuthentication = false;
        settings.KbdInteractiveAuthentication = false;
      };

      networking.firewall = {
        allowedTCPPorts = [
          3000 # Plex MPV Shim control
        ];
        allowedUDPPorts = [
          32410 # Plex GDM discovery
          32412
          32413
          32414
        ];
        allowedUDPPortRanges = [
          {
            from = 60000;
            to = 61000;
          } # Mosh
        ];
      };

      system.stateVersion = "25.05";
    };
}
