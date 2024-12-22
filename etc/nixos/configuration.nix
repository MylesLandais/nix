# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs,inputs,extra-types, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      #<home-manager/nixos>
    ];

  # systemd-boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # network config

  networking.hostName = "kraken"; # Define your hostname.
  networking.search = ["universe.home"];
  networking.nameservers = ["192.168.0.2" "192.168.0.1"];
  nix.settings.experimental-features = ["nix-command" "flakes"];
  nix.nixPath = ["nixpkgs=${inputs.nixpkgs}"];
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "Europe/Madrid";

  i18n.defaultLocale = "en_US.UTF-8";
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    nvidiaSettings = true;

  };
  virtualisation.docker.enable = true;
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
    sugarCandyNix ={
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
  programs.firefox.enable = true;
  programs.steam.enable = true;
  programs.hyprland.enable = true;
  programs.hyprland.xwayland.enable = true;
  security.rtkit.enable = true;
  fonts.packages = with pkgs; [
   nerd-fonts.hack
];
  users.defaultUserShell = pkgs.zsh;
  users.users.franky = {
   isNormalUser = true;
   description = "franky";
   extraGroups = ["networkmanager" "wheel" "docker"];
   packages = with pkgs; [
     nixfmt-rfc-style
     nixd
   ];
};
  nixpkgs.config.allowUnfree = true;


  
  environment.systemPackages = [
    inputs.zen-browser.packages."x86_64-linux".specific
   ];

  system.stateVersion = "24.11"; # Did you read the comment?

}

