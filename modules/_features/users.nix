{ pkgs, ... }:
{
  users.defaultUserShell = pkgs.fish;

  users.users.warby = {
    isNormalUser = true;
    description = "warby";
    # Required by the hermes-agent Home Manager module. Without linger, systemd
    # stops the user manager at logout and takes the hermes gateway and web
    # dashboard down with it.
    linger = true;
    extraGroups = [
      "audio"
      "disk"
      "docker"
      "input"
      "kvm"
      "networkmanager"
      "render"
      "video"
      "wheel"
    ];
    packages = with pkgs; [
      neovim
      vesktop
      mpv
    ];
  };
}
