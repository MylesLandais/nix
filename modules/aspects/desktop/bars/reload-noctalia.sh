if [ -n "${WAYLAND_DISPLAY:-}" ]; then
  # Tear down the previous reload scope first. `--collect` only removes
  # a scope once its cgroup is empty, and noctalia leaves helpers
  # (wl-paste, nmcli) running in it, so the scope stays "active" after
  # the shell itself dies. Reusing the fixed `-u` name would then fail
  # with "already loaded", silently leaving no bar. Stop it outright.
  $DRY_RUN_CMD @NIX1@/bin/systemctl --user stop noctalia-shell-reload.scope || true
  $DRY_RUN_CMD @NIX2@/bin/pkill -f 'bin/quickshell' || true
  if [ -z "${DRY_RUN_CMD:-}" ]; then
    # Wait for every quickshell process to actually exit before
    # relaunching. A fixed `sleep` races a slow (or multiple
    # concurrent) graceful shutdown: the replacement starts while the
    # previous instance still holds quickshell's single-instance IPC
    # lock and immediately exits. Escalate to SIGKILL if one lingers.
    i=0
    while [ "$i" -lt 50 ] && @NIX3@/bin/pgrep -f 'bin/quickshell' > /dev/null 2>&1; do
      @NIX4@/bin/sleep 0.2
      i=$((i + 1))
    done
    if @NIX5@/bin/pgrep -f 'bin/quickshell' > /dev/null 2>&1; then
      @NIX6@/bin/pkill -9 -f 'bin/quickshell' || true
      @NIX7@/bin/sleep 0.5
    fi
    @NIX8@/bin/systemctl --user reset-failed noctalia-shell-reload.scope >/dev/null 2>&1 || true
    # home-manager's activation service runs with a bare environment:
    # hm-setup-env imports only WAYLAND_DISPLAY/DISPLAY/DBUS_SESSION_BUS_ADDRESS/
    # XDG_RUNTIME_DIR, and the unit itself sets QT_QPA_PLATFORM=offscreen.
    # `systemd-run --scope` inherits that environment, so a relaunched
    # noctalia would come up with no panel backend ("No PanelWindow
    # backend loaded") and exit within ~2s.
    #
    # Set QT_QPA_PLATFORM to exactly what the compositor gives session
    # children (Hyprland's `hl.env` in modules/hosts/cerberus/_home.nix,
    # which keybind clients also inherit). quickshell derives the IPC
    # instance's "display connection" identity from it (qs
    # src/launch/command.cpp getDisplayConnection): unset or exactly
    # "wayland" yields "wayland,wayland-1", while a compound value
    # yields "unk,wayland" — and an `ipc call` keybind only talks to an
    # instance with a matching identity.
    export QT_QPA_PLATFORM='wayland;xcb'
    # Same for the icon theme (hl.env QS_ICON_THEME in hypr.nix):
    # without it name-only desktop icons resolve against hicolor only.
    export QS_ICON_THEME='@NIX9@'
    # HYPRLAND_INSTANCE_SIGNATURE is needed for Hyprland IPC features.
    hypr_sig=$(@NIX10@/bin/systemctl --user show-environment | @NIX11@/bin/sed -n 's/^HYPRLAND_INSTANCE_SIGNATURE=//p')
    if [ -n "$hypr_sig" ]; then
      export HYPRLAND_INSTANCE_SIGNATURE="$hypr_sig"
    fi
    # PATH likewise has to be the session's, not activation's (which is
    # only coreutils/sed/etc.). On Hyprland's Lua dispatch syntax
    # noctalia switches workspaces by exec'ing `hyprctl dispatch …`
    # from PATH, so a relaunch without it left workspace clicks dead
    # while everything over the IPC socket kept working.
    session_path=$(@NIX12@/bin/systemctl --user show-environment | @NIX13@/bin/sed -n 's/^PATH=//p')
    if [ -n "$session_path" ]; then
      export PATH="$session_path"
    fi
    # noctalia's clipboard history spawns `wl-paste --type text|image
    # --watch cliphist store` helpers that outlive it. Each reload left
    # another pair behind (ppid 1), so every copy was stored, and read
    # across the XWayland bridge, once per surviving pair.
    @NIX14@/bin/pkill -f '^wl-paste --type (text|image) --watch cliphist store$' || true
    noctalia_bin=@NIX15@/bin/noctalia-shell
    # On Hyprland, have the compositor spawn it, exactly like the login
    # exec-once. Apps opened from the launcher (app2unit's default scope
    # mode) inherit noctalia's environment, and the variables exported
    # above are only a fraction of the session's: a systemd-run relaunch
    # left launched apps without XDG_SESSION_TYPE, XDG_CURRENT_DESKTOP,
    # NIXOS_OZONE_WL, SSH_AUTH_SOCK, the NVIDIA hl.env set, and so on.
    # Electron 38+ then falls back to XWayland.
    if [ -n "$hypr_sig" ] && command -v hyprctl > /dev/null \
      && hyprctl dispatch "hl.dsp.exec_cmd(\"$noctalia_bin\")" > /dev/null 2>&1; then
      :
    else
      # `--scope` execs as the target process itself (it doesn't fork a
      # child and return) — it has to be backgrounded here, or activation
      # blocks until the shell daemon exits. Registering the scope is
      # what matters and happens synchronously before that exec, so the
      # backgrounded job is already outside home-manager-warby.service's
      # cgroup by the time this shell returns.
      @NIX16@/bin/systemd-run --user --scope --collect \
        -u noctalia-shell-reload \
        "$noctalia_bin" >/dev/null 2>&1 &
    fi
  fi
fi
