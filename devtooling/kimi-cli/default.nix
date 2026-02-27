{ pkgs, lib, config, inputs, ... }:
{
  options.kimi-cli.enable = lib.mkEnableOption "Enable kimi-cli Moonshot AI code agent";
  config = lib.mkIf config.kimi-cli.enable {
    home.packages = [ inputs.kimi-cli.packages.${pkgs.system}.default ];
    home.activation.kimiConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -f "$HOME/.kimi/config.toml" ]; then
        mkdir -p "$HOME/.kimi"
        cat > "$HOME/.kimi/config.toml" <<'EOF'
default_model = ""
default_thinking = true
EOF
      fi
    '';
  };
}
