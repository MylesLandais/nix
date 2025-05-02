{
  config,
  lib,
  pkgs,
  inputs,
  extra-types,
  ...
}:
{
  services.ollama = {
    enable = true;
    port = 11434;
    host = "0.0.0.0";
    openFirewall = true;
    acceleration = "cuda";
    loadModels = [
      "qwen2.5-coder:14b"
    ];
  };
  services.open-webui = {
    enable = true;
    openFirewall = true;
    environment = {
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
      WEBUI_AUTH = "False";
    };
    host = "192.168.0.38";
    port = 8088;
  };
}
