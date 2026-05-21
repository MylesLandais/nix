{ config, ... }:
{
  users.users.warby.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINQPlTg3O6tXvjOO8+hVGWfu7tr2lzgAdu+EFVNV2BYY landais.myles@gmail.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIONcu7pQIpReczEW77P9eW7vtte0PTVs9gGck/wyNVYZ warby@warbpad"
  ];

  # Mirror warby's keys to root so a single user-account drift can never strand
  # us. PermitRootLogin = prohibit-password keeps password auth blocked.
  users.users.root.openssh.authorizedKeys.keys =
    config.users.users.warby.openssh.authorizedKeys.keys;

  services.openssh.settings.PermitRootLogin = "prohibit-password";
}
