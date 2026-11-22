{ inputs, ... }: {
  flake.modules.nixos.cerberus =
    {
      config,

      lib,
      pkgs,
      ...
    }:
    {
      imports = [
        inputs.self.modules.nixos.cerberusHardware
        inputs.self.modules.nixos.sshKeys
        inputs.self.modules.nixos.nvidia
        inputs.self.modules.nixos.gpuUnlock
        inputs.self.modules.nixos.gaming
        inputs.self.modules.nixos.gitMirrors
        inputs.self.modules.nixos.dev
        inputs.self.modules.nixos.agenixHost
        inputs.self.modules.nixos.chromiumPolicy
        inputs.self.modules.nixos.audio
        inputs.self.modules.nixos.sunshine
        inputs.self.modules.nixos.fileSharing
        inputs.self.modules.nixos.syncthing
        inputs.self.modules.nixos.hardwareTuning
        inputs.self.modules.nixos.workspaceBudget
        inputs.self.modules.nixos.waydroidFeh
        inputs.self.modules.nixos.pokeforce
        inputs.self.modules.nixos.fhsCompat
        inputs.self.modules.nixos.security
        inputs.self.modules.nixos.users
        inputs.self.modules.nixos.firefoxPolicy
        inputs.self.modules.nixos.infraContract
        inputs.self.modules.nixos.infraSecrets
        inputs.self.modules.nixos.infraIngress
        inputs.self.modules.nixos.profileInfraSpine
        inputs.self.modules.nixos.profileDemoCerberus
        inputs.self.modules.nixos.postgresInfra
        inputs.self.modules.nixos.valkeyInfra
        inputs.self.modules.nixos.seaweedfsInfra
        inputs.self.modules.nixos.openbaoInfra
        inputs.self.modules.nixos.traefikInfra
        inputs.self.modules.nixos.authentikInfra
        inputs.self.modules.nixos.pyloadInfra
        inputs.self.modules.nixos.mayaWorkerInfra
        inputs.self.modules.nixos.agenixInfra
        inputs.self.modules.nixos.llmRouter
        inputs.self.modules.nixos.deepseekHarnessInfra
      ];

      networking.hostName = config.host.hostName;

      # gpu-unlock: the DEFAULT entry unlocks the 3090 Ti upstream 2.0
      # (tracking Zagitta/gpu-unlock main). The stock comparison is the
      # previous boot generation, not a specialisation: keeping the unlock in
      # a specialisation forever meant the running system never measured it.
      # Revert by switching back a generation. A/B protocol and stock
      # baselines: ~/Vault/nix-issues/gpu-unlock-ab.md.
      hardware.gpuUnlock = {
        enable = true;
        targets = "0000:2b:00.0";
      };

      nixpkgs.overlays = [
        (import "${inputs.self}/modules/aspects/packages/overlays/_cursor.nix")
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
        gamehacking.enable = true;
        citraAgent = {
          enable = true;
          gameRoot = "/home/warby/Games/roms/3ds";
        };
        iw4x.enable = true;
        pokeforce.enable = true;
        scbw.enable = true;
        warcraft3.enable = true;
        remoteGaming.enable = true;
        syncthing.enable = true;
        # Hyprland's bundled wall2.png (the girl on the train).
        wallpaper = "${pkgs.hyprland}/share/hypr/wall2.png";
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

      # GitHub -> Forgejo pull mirrors. The server pulls; this box only runs
      # the one-shot setup/sync command (Bitwarden unlock is human-in-the-loop):
      #   bw login   # one time per machine
      #   export BW_SESSION=$(bw unlock --raw) && forgejo-mirror-sync
      # See modules/services/git-mirrors.nix for the mapping and token items.
      services.infra.gitMirrors.enable = true;

      # Agent harness driving the router above; see /etc/deepseek-harness/env.
      services.infra.deepseek-harness.enable = true;

      # Canonical object storage for Workspace-internal/maya-unified dev
      # projects, replacing the Docker container `dev.seaweedfs`. See
      # docs/infra/README.md "Shared developer services".
      services.infra.seaweedfs.enable = true;
      services.infra.seaweedfs.volumeMax = 1850;

      nix.settings.trusted-users = [
        "root"
        "warby"
        "@wheel"
      ];

      boot = {
        plymouth.enable = true;
        consoleLogLevel = 3;
        loader = {
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
        };
        # CachyOS kernel from chaotic-nyx (overlay via chaotic.nixosModules.default
        # in default.nix). The kernel and its nvidia-open module are both served
        # from nyx-cache.chaotic.cx, which already supplies the NVIDIA userspace.
        # Replaced xddxdd/nix-cachyos-kernel on 2026-10-22 after its cache was
        # compromised (github.com/xddxdd/nix-cachyos-kernel/issues/110).
        kernelPackages = pkgs.linuxPackages_cachyos;
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

      services.tailscale = {
        enable = true;
        # Resolve private tailnet hostnames through MagicDNS.
        extraSetFlags = [ "--accept-dns=true" ];
      };

      services.fehWaydroid = {
        enable = true;
        user = "warby";
        width = 720;
        height = 1280;
        useNftables = true;
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

        # Hermes dashboard, tailnet-only. The backend binds the MagicDNS name
        # (see modules/_hermes.nix), never the LAN address, and the port is
        # accepted on tailscale0 alone — deliberately not in allowedTCPPorts,
        # which would open it to the whole LAN.
        interfaces."tailscale0".allowedTCPPorts = [ 9119 ];
      };

      system.stateVersion = "25.05";
    };
}
