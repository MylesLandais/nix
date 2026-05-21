{ inputs, lib, ... }:
{
  flake.nixosConfigurations.hypr-v = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      "${inputs.nixos-generators}/format-module.nix"
      "${inputs.nixos-generators}/formats/hyperv.nix"

      inputs.self.nixosModules.themeData
      inputs.self.nixosModules.greeter
      inputs.self.nixosModules.wifiProfiles

      "${inputs.self}/modules/features/host-options.nix"
      "${inputs.self}/modules/features/env-packages.nix"
      "${inputs.self}/modules/features/nix-config.nix"
      "${inputs.self}/modules/features/fish-config.nix"

      inputs.home-manager.nixosModules.home-manager
      {
        home-manager = {
          useUserPackages = true;
          useGlobalPkgs = true;
          sharedModules = [ inputs.agenix.homeManagerModules.age ];
          users.warby =
            { ... }:
            {
              imports = [ "${inputs.self}/modules/home.nix" ];
              home.username = lib.mkForce "warby";
              home.homeDirectory = lib.mkForce "/home/warby";
              age.identityPaths = lib.mkForce [ "/home/warby/.ssh/age" ];
            };
          extraSpecialArgs = {
            inherit inputs;
            system = "x86_64-linux";
          };
        };
      }

      (
        { pkgs, lib, ... }:
        {
          host = {
            hostName = "hypr-v";
            class = "desktop";
            isDesktop = true;
            bar = "hyprpanel";
            greeter = "sddm";
            theme = "kanagawa-dragon";
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

          nixpkgs.config.allowUnfree = true;

          networking.hostName = lib.mkForce "hypr-v";

          environment.pathsToLink = [
            "/share/applications"
            "/share/xdg-desktop-portal"
          ];

          virtualisation.hypervGuest.enable = true;

          services.openssh = {
            enable = true;
            settings.PermitRootLogin = lib.mkForce "prohibit-password";
          };

          users.users.warby = {
            isNormalUser = true;
            extraGroups = [ "wheel" "networkmanager" "video" ];
            initialPassword = "warby";
            shell = pkgs.fish;
          };

          system.stateVersion = "25.11";
        }
      )
    ];
  };

  perSystem = _: {
    packages.hypr-v =
      inputs.self.nixosConfigurations.hypr-v.config.system.build.hypervImage;
  };
}
