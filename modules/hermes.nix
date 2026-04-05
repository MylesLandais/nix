{
  config,
  ...
}:

{
  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;

    environmentFiles = [
      config.age.secrets.hermes-env.path
    ];

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
