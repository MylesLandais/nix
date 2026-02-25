{ pkgs, lib, config, inputs, ... }:
{
  options.kimi-cli.enable = lib.mkEnableOption "Enable kimi-cli Moonshot AI code agent";
  config = lib.mkIf config.kimi-cli.enable {
    home.packages = [ inputs.kimi-cli.packages.${pkgs.system}.default ];
    home.file.".kimi/config.toml".text = ''
      default_model = "kimi-k2.5"
      default_thinking = true
    '';
  };
}
