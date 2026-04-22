# Hermes agent for lacie — reads API key from persistent_data partition.
# Drop credentials at /mnt/data/secrets/hermes.env before first boot.
# Format: ANTHROPIC_API_KEY=sk-ant-...
{ ... }:
{
  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;

    environmentFiles = [
      "/mnt/data/secrets/hermes.env"
    ];

    settings = {
      model = "claude-opus-4-5";
      terminal.backend = "local";
      toolsets = [ "all" ];
    };

    documents = {
      "SOUL.md" = ''
        You are Hermes, an AI agent on a portable NixOS workstation running from a LaCie 5TB USB drive.
        You have local terminal access. The system boots from the live_nix ext4 partition.
        Config lives at /nix-configs (flake target: lacie).
        To rebuild: sudo nixos-rebuild switch --flake /nix-configs#lacie
        Be concise and direct. Help with NixOS config, system administration, and development tasks.
      '';
    };
  };
}
