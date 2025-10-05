let
  franky = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFyWsnvAIM23SRQCW4AIPKeNhVeCWtez/CV1hDegCunC franky@kraken";
  kraken = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFyWsnvAIM23SRQCW4AIPKeNhVeCWtez/CV1hDegCunC franky@kraken";
in
{
  "ollama.age".publicKeys = [
    franky
    kraken
  ];

  # Add Tailscale auth key (replace with your actual key; encrypt via sops)
  sops.secrets."tailscale-auth-key" = {
    key = "age1...";  # Encrypted age file content for tskey-auth-...
    owner = "root";
  };

  # Code-server password (generate strong one, encrypt)
  sops.secrets."code-server-password" = {
    key = "age1...";  # Encrypted
    owner = "franky";  # Or system user
  };
}
