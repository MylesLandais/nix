let
  warby = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINQPlTg3O6tXvjOO8+hVGWfu7tr2lzgAdu+EFVNV2BYY landais.myles@gmail.com";
  system = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINQPlTg3O6tXvjOO8+hVGWfu7tr2lzgAdu+EFVNV2BYY landais.myles@gmail.com"; # Using same key for system decryption
  users = [ warby ];
  systems = [ system ];
in
{
  "ollama.age".publicKeys = users ++ systems;
  "anthropic-api-key.age".publicKeys = users ++ systems;
  "zai-api-key.age".publicKeys = users ++ systems;
  "tailscale-auth-key.age".publicKeys = users ++ systems;
  "code-server-password.age".publicKeys = users ++ systems;
}
