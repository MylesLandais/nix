{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

{
  # Agenix for secrets management
  age = {
    secrets = {
      tailscale-auth-key = {
        file = ../../secrets/tailscale-auth-key.age;
        owner = "root";
      };
      code-server-password = {
        file = ../../secrets/code-server-password.age;
        owner = "warby";
      };
      ollama = {
        file = ../../secrets/ollama.age;
        owner = "root";
      };
    };
  };

  environment.systemPackages = [ inputs.agenix.packages.${pkgs.system}.agenix ];
}
