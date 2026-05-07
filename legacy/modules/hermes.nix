# TODO(unsolved): ~/.hermes/config.yaml is NOT managed by Nix. It is a live user
# file that hermes reads directly and it takes precedence over any settings defined
# in the services.hermes-agent.settings block below. Changes made here (model,
# terminal.backend, etc.) may be silently ignored if config.yaml defines the same
# keys. There is currently no mechanism to manage config.yaml via home.file or
# similar because the hermes module does not expose a way to disable its own
# config generation. Until resolved, treat config.yaml as the source of truth for
# runtime settings and keep this block as documentation only.
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
