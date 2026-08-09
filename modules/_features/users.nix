{ pkgs, ... }:
{
  users.defaultUserShell = pkgs.fish;

  users.users.warby = {
    isNormalUser = true;
    description = "warby";
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
