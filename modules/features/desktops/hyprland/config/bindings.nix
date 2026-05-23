{ lib, bar, ... }:
{
  "$mod" = "SUPER";

  bind =
    [
      "$mod, RETURN, exec, ghostty"
      "$mod, W, exec, helium"
      "$mod, D, exec, vesktop --enable-features=UseOzonePlatform --ozone-platform=wayland --ozone-platform-hint=auto"
      "$mod, Q, killactive,"
      "$mod, M, exit,"
      "$mod, E, exec, nemo"
      "$mod, V, togglefloating,"
      "$mod, P, exec, cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"
      "$mod, H, movefocus, l"
      "$mod, L, movefocus, r"
      "$mod, K, movefocus, u"
      "$mod, J, movefocus, d"
      "$mod SHIFT, H, movewindow, l"
      "$mod SHIFT, L, movewindow, r"
      "$mod SHIFT, K, movewindow, u"
      "$mod SHIFT, J, movewindow, d"
      "$mod, mouse_down, workspace, e+1"
      "$mod, mouse_up, workspace, e-1"
      ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
      ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
    ]
    ++ lib.optionals (bar == "noctalia") [
      "$mod, B, exec, noctalia-shell ipc call lockScreen lock"
      "$mod, F, exec, noctalia-shell ipc call launcher toggle"
      "$mod, S, exec, hyprshot -m region --clipboard-only"
      "$mod SHIFT, R, exec, noctalia-shell ipc call sessionMenu toggle"
      "$mod, X, exec, noctalia-shell ipc call settings toggle"
      "$mod SHIFT, S, exec, obs"
      "$mod SHIFT, N, exec, noctalia-shell ipc call nightLight toggle"
      "$mod, N, exec, noctalia-shell ipc call notifications toggleHistory"
      "$mod SHIFT, W, exec, noctalia-shell ipc call wallpaper toggle"
      "$mod SHIFT, C, exec, noctalia-shell ipc call controlCenter toggle"
    ]
    ++ (builtins.concatLists (
      builtins.genList (
        i:
        let
          ws = toString (i + 1);
        in
        [
          "$mod, code:1${toString i}, workspace, ${ws}"
          "$mod SHIFT, code:1${toString i}, movetoworkspace, ${ws}"
        ]
      ) 9
    ));

  bindm = [
    "$mod, mouse:272, movewindow"
    "$mod, mouse:273, resizewindow"
  ];
}
