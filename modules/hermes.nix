{
  config,
  ...
}:

{
  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;

    # Uncomment after creating the secret: agenix -e secrets/hermes-env.age
    # Contents should be KEY=VALUE format: OPENROUTER_API_KEY=... and GLM_API_KEY=...
    # Also uncomment the hermes-env block in modules/agenix.nix
    # environmentFiles = [
    #   config.age.secrets.hermes-env.path
    # ];

    settings = {
      model = "anthropic/claude-sonnet-4";
      terminal.backend = "local";
      toolsets = [ "all" ];
    };

    documents = {
      "SOUL.md" = ''
        You are Hermes, an AI agent on a NixOS workstation named Cerberus.
        You have local terminal access. Be concise and direct.
      '';
    };
  };
}
