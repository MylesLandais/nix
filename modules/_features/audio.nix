_: {
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;

    # Floor for PulseAudio clients (browsers, Electron, games). Small
    # client-requested quanta under a saturated CPU are what crackle; 1024
    # frames at 48 kHz (~21 ms) is still inaudible latency for streams.
    extraConfig.pipewire-pulse."92-low-jitter" = {
      "pulse.properties" = {
        "pulse.min.req" = "1024/48000";
        "pulse.min.quantum" = "1024/48000";
        "pulse.min.frag" = "1024/48000";
      };
    };

    # Virtual audio sink for isolated Sunshine streaming
    extraConfig.pipewire."99-sunshine-sink" = {
      "context.objects" = [
        {
          factory = "adapter";
          args = {
            "factory.name" = "support.null-audio-sink";
            "node.name" = "sunshine_sink";
            "node.description" = "Sunshine Streaming Sink";
            "media.class" = "Audio/Sink";
            "audio.position" = "FL,FR";
          };
        }
      ];
    };
  };
}
