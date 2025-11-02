{
  pkgs,
  vars,
  config,
  inputs,
  ...
}:
let
  add_record_player = pkgs.writeShellApplication {
    name = "add_record_player";
    text = ''
      # Wait a moment for audio services to fully start
      sleep 2
      # Set PCM2900C input volume to 100%
      pactl set-source-volume alsa_input.usb-BurrBrown_from_Texas_Instruments_USB_AUDIO_CODEC-00.pro-input-0 65536
      # Unmute PCM2900C input
      pactl set-source-mute alsa_input.usb-BurrBrown_from_Texas_Instruments_USB_AUDIO_CODEC-00.pro-input-0 false
      # Set Scarlett Solo output volume to 100%
      pactl set-sink-volume alsa_output.usb-Focusrite_Scarlett_Solo_USB_Y7RBNDQ2A68E32-00.pro-output-0 65536
      # Unmute Scarlett Solo output
      pactl set-sink-mute alsa_output.usb-Focusrite_Scarlett_Solo_USB_Y7RBNDQ2A68E32-00.pro-output-0 false
      # Create loopback from PCM2900C input to Scarlett Solo output
      pactl load-module module-loopback source=alsa_input.usb-BurrBrown_from_Texas_Instruments_USB_AUDIO_CODEC-00.pro-input-0 sink=alsa_output.usb-Focusrite_Scarlett_Solo_USB_Y7RBNDQ2A68E32-00.pro-output-0
      echo "PCM2900C to Scarlett Solo loopback configured successfully"
    '';
  };
in
{
  home.packages = [
    add_record_player
  ];
  services.hyprpaper = {
    enable = true;
    package = pkgs.hyprpaper;
    settings = {
      ipc = "on";
      splash = false;
      preload = [ vars.wallpaper ];
      wallpaper = [
        "${vars.mainMonitor.name},${vars.wallpaper}"
        "${vars.secondaryMonitor.name},${vars.wallpaper}"
        "${vars.tertiaryMonitor.name},${vars.wallpaper}"
        "${vars.fourthMonitor.name},${vars.wallpaper}"
      ];
    };
  };
  dbus.packages = [
    pkgs.pass-secret-service
    pkgs.gcr
    pkgs.gnome-settings-daemon
    pkgs.libsecret
  ];
  programs.kitty = {
    enable = true;
    settings = {
      font_family = "Hack Nerd Font";
      bold_font = "auto";
      italic_font = "auto";
      bold_italic_font = "auto";
      enable_audio_bell = false;
      scrollback_lines = -1;
      tab_bar_edge = "top";
      allow_remote_control = "yes";
    };
    shellIntegration = {
      enableZshIntegration = true;
    };
    themeFile = "kanagawa";
  };

}
