{ lib, mod, bar }:
let
  bind = keys: action: "hl.bind(\"${keys}\", ${action})";
  optsToLua = opts:
    "{ " + lib.concatStringsSep ", "
      (lib.mapAttrsToList (k: v: "${k} = ${lib.boolToString v}") opts) + " }";
  bindO = keys: action: opts:
    "hl.bind(\"${keys}\", ${action}, ${optsToLua opts})";
  exec = cmd: "hl.dsp.exec_cmd(\"${cmd}\")";
  focus = dir: "hl.dsp.focus({ direction = \"${dir}\" })";
  wMove = dir: "hl.dsp.window.move({ direction = \"${dir}\" })";
  wsSwitch = ws: "hl.dsp.focus({ workspace = ${ws} })";
  wsMoveTo = ws: "hl.dsp.window.move({ workspace = ${ws} })";
in
''
  ${bind "${mod} + RETURN"          (exec "ghostty")}
  ${bind "${mod} + W"               (exec "helium")}
  ${bind "${mod} + D"               (exec "vesktop --enable-features=UseOzonePlatform --ozone-platform=wayland --ozone-platform-hint=auto")}
  ${bind "${mod} + Q"               "hl.dsp.window.close()"}
  ${bind "${mod} + M"               "hl.dsp.exit()"}
  ${bind "${mod} + E"               (exec "nemo")}
  ${bind "${mod} + V"               "hl.dsp.window.float()"}
  ${bind "${mod} + P"               (exec "cliphist list | fuzzel --dmenu | cliphist decode | wl-copy")}
  ${bind "${mod} + H"               (focus "l")}
  ${bind "${mod} + L"               (focus "r")}
  ${bind "${mod} + K"               (focus "u")}
  ${bind "${mod} + J"               (focus "d")}
  ${bind "${mod} + SHIFT + H"       (wMove "l")}
  ${bind "${mod} + SHIFT + L"       (wMove "r")}
  ${bind "${mod} + SHIFT + K"       (wMove "u")}
  ${bind "${mod} + SHIFT + J"       (wMove "d")}
  ${bind "${mod} + mouse_down"      (wsSwitch "\"e+1\"")}
  ${bind "${mod} + mouse_up"        (wsSwitch "\"e-1\"")}
  ${bind "XF86AudioRaiseVolume"     (exec "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+")}
  ${bind "XF86AudioLowerVolume"     (exec "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")}
  ${bindO "${mod} + mouse:272"      "hl.dsp.window.drag()"   { mouse = true; }}
  ${bindO "${mod} + mouse:273"      "hl.dsp.window.resize()" { mouse = true; }}
''
+ lib.optionalString (bar == "noctalia") ''
  ${bind "${mod} + B"               (exec "noctalia-shell ipc call lockScreen lock")}
  ${bind "${mod} + R"               (exec "noctalia-shell ipc call launcher toggle")}
  ${bind "${mod} + S"               (exec "hyprshot -m region --clipboard-only")}
  ${bind "${mod} + SHIFT + R"       (exec "noctalia-shell ipc call sessionMenu toggle")}
  ${bind "${mod} + X"               (exec "noctalia-shell ipc call settings toggle")}
  ${bind "${mod} + SHIFT + S"       (exec "obs")}
  ${bind "${mod} + SHIFT + N"       (exec "noctalia-shell ipc call nightLight toggle")}
  ${bind "${mod} + N"               (exec "noctalia-shell ipc call notifications toggleHistory")}
  ${bind "${mod} + SHIFT + W"       (exec "noctalia-shell ipc call wallpaper toggle")}
  ${bind "${mod} + SHIFT + C"       (exec "noctalia-shell ipc call controlCenter toggle")}
''
+ (builtins.concatStringsSep "\n" (
    builtins.genList (
      i:
      let
        ws = toString (i + 1);
        key = toString (i + 10);
      in
      ''
        ${bind "${mod} + code:${key}"         (wsSwitch ws)}
        ${bind "${mod} + SHIFT + code:${key}" (wsMoveTo ws)}
      ''
    ) 9
  ))