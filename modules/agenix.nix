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
      # tailscale-auth-key = {
      #   file = ../secrets/tailscale-auth-key.age;
      #   owner = "root";
      # };
      # code-server-password = {
      #   file = ../secrets/code-server-password.age;
      #   owner = "warby";
      # };
      ollama = {
        file = ../secrets/ollama.age;
        owner = "root";
      };
      # anthropic-api-key = {
      #   file = ../secrets/anthropic-api-key.age;
      #   owner = "warby";
      # };
      zai-api-key = {
        file = ../secrets/zai-api-key.age;
        owner = "warby";
      };
    };
  };

  environment.systemPackages = [ inputs.agenix.packages.${pkgs.system}.agenix ];
}
