# Shared base of the Dell 7050 cluster nodes (94tl0m2, 95qmom2). Each host
# passes only what differs: its hostname and any extra packages.
{
  hostName,
  extraPackages ? _: [ ],
}:
{ pkgs, inputs, ... }:
{
  imports = [ inputs.self.modules.nixos.sshKeys ];

  networking.hostName = hostName;

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelParams = [
      "quiet"
      "loglevel=3"
    ];
  };

  networking = {
    useDHCP = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22
      ];
    };
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      UseDns = false;
    };
  };

  services.tailscale.enable = true;

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  services.journald.settings.Journal = {
    SystemMaxUse = "500M";
    MaxFileSec = "7day";
  };

  users = {
    defaultUserShell = pkgs.fish;
    users.warby = {
      isNormalUser = true;
      description = "warby";
      extraGroups = [
        "wheel"
        "docker"
        "video"
        "render"
        "disk"
      ];
      hashedPassword = "";
    };
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages =
    (with pkgs; [
      git
      vim
      wget
      curl
      htop
      btop
      tmux
      ripgrep
      fd
      pciutils
      usbutils
      smartmontools
      docker-compose
      tailscale
    ])
    ++ extraPackages pkgs;

  programs.fish.enable = true;

  nix.settings.trusted-users = [
    "root"
    "warby"
    "@wheel"
  ];

  system.stateVersion = "25.11";
}
