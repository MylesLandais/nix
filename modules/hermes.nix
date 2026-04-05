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
      model = "qwen/qwen3-6-plus:free";
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
