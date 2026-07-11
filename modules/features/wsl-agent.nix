{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [ inputs.nixos-wsl.nixosModules.default ];

  options.wslAgent = {
    enable = lib.mkEnableOption "NixOS-WSL reproducible coding-agent workstation profile";

    defaultUser = lib.mkOption {
      type = lib.types.str;
      default = "warby";
      description = "Default WSL login user.";
    };

    codeServer = {
      enable = lib.mkEnableOption "code-server on mirrored localhost" // {
        # Enable per host only after provisioning a secret-backed password.
        default = false;
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8443;
        description = "code-server listen port.";
      };
    };
  };

  config = lib.mkIf config.wslAgent.enable {
    wsl = {
      enable = true;
      defaultUser = config.wslAgent.defaultUser;
      startMenuLaunchers = true;
      interop = {
        includePath = true;
        register = true;
      };
    };

    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
    };

    programs = {
      fish.enable = true;
      nix-ld.enable = true;
    };

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "prohibit-password";
      };
    };

    services.code-server = lib.mkIf config.wslAgent.codeServer.enable {
      enable = true;
      user = config.wslAgent.defaultUser;
      host = "127.0.0.1";
      port = config.wslAgent.codeServer.port;
      auth = "password";
      extraArguments = [ "--disable-telemetry" ];
    };

    environment.systemPackages = with pkgs; [
      git
      gh
      curl
      wget
      jq
      ripgrep
      fd
      fzf
      tmux
      just
      nodejs_24
      bun
      python313
      uv
      go
    ];
  };
}
