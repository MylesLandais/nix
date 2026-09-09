_: {
  flake.modules.nixos."7PZSZY2" =
    { pkgs, ... }:
    {
      nixpkgs.config.allowUnfree = true;

      # Dell Service Tag for the Windows 11 laptop hosting this WSL instance.
      # Query from Windows with:
      #   (Get-CimInstance -ClassName Win32_BIOS).SerialNumber
      networking.hostName = "7pzszy2";

      wslAgent = {
        enable = true;
        defaultUser = "warby";
      };

      networking.firewall = {
        enable = true;
        allowedTCPPorts = [ 22 ];
      };

      time.timeZone = "America/Chicago";
      i18n.defaultLocale = "en_US.UTF-8";

      virtualisation.docker = {
        enable = true;
        enableOnBoot = true;
      };

      users = {
        defaultUserShell = pkgs.fish;
        users.warby = {
          isNormalUser = true;
          description = "warby";
          extraGroups = [
            "wheel"
            "docker"
          ];
          hashedPassword = "";
        };
      };

      security.sudo.wheelNeedsPassword = false;

      nix.settings.trusted-users = [
        "root"
        "warby"
        "@wheel"
      ];

      system.stateVersion = "26.05";
    };
}
