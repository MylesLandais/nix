_: {
  flake.nixosModules.cerberus =
    {
      inputs,
      lib,
      ...
    }:
    {
      imports = [
        "${inputs.self}/hosts/cerberus/configuration.nix"
        "${inputs.self}/modules/features/ssh-keys.nix"
      ];

      nixpkgs.overlays = [
        inputs.nur.overlays.default
        inputs.claude-code.overlays.default
        inputs.nix-vscode-extensions.overlays.default
        inputs.nix-cachyos-kernel.overlays.pinned
      ];

      host = {
        hostName = "cerberus-nix";
        isDesktop = true;
        class = "desktop";
        bar = "noctalia";
        desktop = "hyprland";
        greeter = "greetd";
        gpuType = "nvidia";
        theme = "kanagawa-dragon";
        profile = "default";
        wallpaper = "${inputs.wallpapers.packages.x86_64-linux.default}/share/wallpapers/kanagawa-dragon/3895e.jpg";
        mainMonitor = {
          name = "desc:Dell Inc. Dell S2716DG ##ASPYT+r5vCzd";
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
    };
}
