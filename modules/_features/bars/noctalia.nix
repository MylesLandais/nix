{
  lib,
  pkgs,
  osConfig,
  config,
  inputs,
  ...
}:
{
  options = {
    bars.noctalia.enable = lib.mkEnableOption "Enable noctalia bar";
  };
  config = lib.mkIf config.bars.noctalia.enable (
    let
      homeDir = config.home.homeDirectory;
    in
    {

      # Install noctalia plugins by copying out of a fetched monorepo. Noctalia
      # writes settings.json / pinned.json / notecards/ inside the plugin dir at
      # runtime, so we can't use a read-only store symlink. Idempotent: only
      # copies if the destination is missing. To pull updates, bump the rev
      # below and delete ~/.config/noctalia/plugins/clipper before rebuilding.
      home.activation.noctaliaClipper =
        let
          plugins = pkgs.fetchFromGitHub {
            owner = "blackbartblues";
            repo = "noctalia-plugins";
            rev = "main";
            hash = "sha256-YGspOSjP6Y7ilW2w8Rp/QEyCkkW/4Cg7lKbC82BzU50=";
          };
        in
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          PLUGIN_DIR="$HOME/.config/noctalia/plugins/clipper"
          if [ ! -e "$PLUGIN_DIR" ]; then
            run mkdir -p "$HOME/.config/noctalia/plugins"
            run cp -r --no-preserve=mode,ownership ${plugins}/clipper "$PLUGIN_DIR"
          fi
        '';

      # Restart noctalia-shell after every rebuild so the launcher index reflects
      # newly installed packages, and — just as importantly — so IPC keybinds
      # (Mod+R launcher, Mod+C clipboard, etc.) keep working at all: noctalia-shell
      # is a plain Hyprland exec-once with no supervision, so whenever a rebuild
      # changes its store path (any nixpkgs bump can do this, not just a direct
      # noctalia change), the running instance is silently orphaned — same store
      # path but a different hash, `noctalia-shell ipc call ...` can no longer
      # find it, and it never restarts on its own.
      #
      # `pgrep -x noctalia-shell` never actually matched here: quickshell execs
      # into the real binary rather than preserving argv[0], so /proc/<pid>/comm
      # is the truncated wrapper name (".quickshell-wra"), not "noctalia-shell" —
      # this whole activation step was a silent no-op. Match on the binary path
      # instead (Quickshell's DesktopEntries inotify watcher also misses NixOS's
      # atomic profile symlink swap and won't fire onValuesChanged on its own).
      #
      # The relaunch has to be `systemd-run --scope`, not a bare backgrounded
      # subshell: activation runs inside home-manager-warby.service's cgroup, and
      # a plain `(cmd &)` gets reaped along with it once activation finishes —
      # confirmed live: the pkill half ran, the relaunch didn't survive, and the
      # launcher was gone until restarted by hand. Only runs inside an active
      # Wayland session.
      home.activation.reloadNoctalia = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -n "''${WAYLAND_DISPLAY:-}" ]; then
          # Tear down the previous reload scope first. `--collect` only removes
          # a scope once its cgroup is empty, and noctalia leaves helpers
          # (wl-paste, nmcli) running in it, so the scope stays "active" after
          # the shell itself dies. Reusing the fixed `-u` name would then fail
          # with "already loaded", silently leaving no bar. Stop it outright.
          $DRY_RUN_CMD ${pkgs.systemd}/bin/systemctl --user stop noctalia-shell-reload.scope || true
          $DRY_RUN_CMD ${pkgs.procps}/bin/pkill -f 'bin/quickshell' || true
          if [ -z "''${DRY_RUN_CMD:-}" ]; then
            # Wait for every quickshell process to actually exit before
            # relaunching. A fixed `sleep` races a slow (or multiple
            # concurrent) graceful shutdown: the replacement starts while the
            # previous instance still holds quickshell's single-instance IPC
            # lock and immediately exits. Escalate to SIGKILL if one lingers.
            i=0
            while [ "$i" -lt 50 ] && ${pkgs.procps}/bin/pgrep -f 'bin/quickshell' > /dev/null 2>&1; do
              ${pkgs.coreutils}/bin/sleep 0.2
              i=$((i + 1))
            done
            if ${pkgs.procps}/bin/pgrep -f 'bin/quickshell' > /dev/null 2>&1; then
              ${pkgs.procps}/bin/pkill -9 -f 'bin/quickshell' || true
              ${pkgs.coreutils}/bin/sleep 0.5
            fi
            ${pkgs.systemd}/bin/systemctl --user reset-failed noctalia-shell-reload.scope >/dev/null 2>&1 || true
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
            # HYPRLAND_INSTANCE_SIGNATURE is needed for Hyprland IPC features.
            hypr_sig=$(${pkgs.systemd}/bin/systemctl --user show-environment | ${pkgs.gnused}/bin/sed -n 's/^HYPRLAND_INSTANCE_SIGNATURE=//p')
            if [ -n "$hypr_sig" ]; then
              export HYPRLAND_INSTANCE_SIGNATURE="$hypr_sig"
            fi
            # PATH likewise has to be the session's, not activation's (which is
            # only coreutils/sed/etc.). On Hyprland's Lua dispatch syntax
            # noctalia switches workspaces by exec'ing `hyprctl dispatch …`
            # from PATH, so a relaunch without it left workspace clicks dead
            # while everything over the IPC socket kept working.
            session_path=$(${pkgs.systemd}/bin/systemctl --user show-environment | ${pkgs.gnused}/bin/sed -n 's/^PATH=//p')
            if [ -n "$session_path" ]; then
              export PATH="$session_path"
            fi
            # `--scope` execs as the target process itself (it doesn't fork a
            # child and return) — it has to be backgrounded here, or activation
            # blocks until the shell daemon exits. Registering the scope is
            # what matters and happens synchronously before that exec, so the
            # backgrounded job is already outside home-manager-warby.service's
            # cgroup by the time this shell returns.
            ${pkgs.systemd}/bin/systemd-run --user --scope --collect \
              -u noctalia-shell-reload \
              ${inputs.noctalia.packages.${pkgs.system}.default}/bin/noctalia-shell >/dev/null 2>&1 &
          fi
        fi
      '';

      programs.noctalia-shell = {
        enable = lib.mkIf (osConfig.host.bar == "noctalia") true;
        # Upstream deprecated the systemd unit; the compositor's execOnce
        # (see modules/features/desktops/hyprland/hypr.nix) launches the
        # shell instead. See https://docs.noctalia.dev/getting-started/nixos/
        systemd.enable = false;
        settings = {
          appLauncher = {
            autoPasteClipboard = false;
            # Launch apps into their own systemd scopes (see hyprland bindings.nix).
            # This noctalia rev ignores useApp2Unit; the prefix is what it honours.
            customLaunchPrefix = "${lib.getExe pkgs.app2unit} --";
            customLaunchPrefixEnabled = true;
            enableClipPreview = true;
            enableClipboardHistory = true;
            iconMode = "tabler";
            ignoreMouseInput = false;
            position = "center";
            screenshotAnnotationTool = "";
            showCategories = true;
            showIconBackground = true;
            sortByMostUsed = true;
            terminalCommand = "ghostty -e";
            useApp2Unit = false;
            viewMode = "list";
          };
          audio = {
            cavaFrameRate = 30;
            externalMixer = "pwvucontrol || pavucontrol";
            mprisBlacklist = [

            ];
            preferredPlayer = "";
            visualizerType = "linear";
            volumeOverdrive = false;
            volumeStep = 5;
          };
          bar = {
            backgroundOpacity = lib.mkForce 0;
            capsuleOpacity = lib.mkForce 1;
            density = lib.mkForce "compact";
            exclusive = lib.mkForce true;
            floating = lib.mkForce true;
            marginHorizontal = lib.mkForce 0.5;
            marginVertical = lib.mkForce 0.15;
            monitors = [

            ];
            outerCorners = false;
            position = "top";
            showCapsule = true;
            showOutline = true;
            useSeparateOpacity = true;
            widgets = {
              center = [
                {
                  characterCount = 1;
                  colorizeIcons = false;
                  enableScrollWheel = true;
                  followFocusedScreen = false;
                  groupedBorderOpacity = 1;
                  hideUnoccupied = false;
                  iconScale = 0.7;
                  id = "Workspace";
                  labelMode = "index";
                  showApplications = false;
                  showLabelsOnlyWhenOccupied = true;
                  unfocusedIconsOpacity = 1;
                }
              ];
              left = [
                {
                  icon = "rocket";
                  id = "Launcher";
                  usePrimaryColor = false;
                }
                {
                  customFont = "";
                  formatHorizontal = "HH:mm";
                  formatVertical = "HH mm - dd MM";
                  id = "Clock";
                  tooltipFormat = "HH:mm ddd, MMM dd";
                  useCustomFont = false;
                  usePrimaryColor = false;
                }
              ];
              right = [
                {
                  blacklist = [

                  ];
                  colorizeIcons = false;
                  drawerEnabled = true;
                  hidePassive = true;
                  id = "Tray";
                  pinned = [

                  ];
                }
                {
                  colorizeDistroLogo = false;
                  colorizeSystemIcon = "none";
                  customIconPath = "";
                  enableColorization = false;
                  icon = "noctalia";
                  id = "ControlCenter";
                  useDistroLogo = true;
                }
              ];
            };
          };
          brightness = {
            brightnessStep = 5;
            enableDdcSupport = true;
            enforceMinimum = true;
          };
          calendar = {
            cards = [
              {
                enabled = true;
                id = "calendar-header-card";
              }
              {
                enabled = true;
                id = "calendar-month-card";
              }
              {
                enabled = true;
                id = "timer-card";
              }
              {
                enabled = true;
                id = "weather-card";
              }
            ];
          };
          colorSchemes = {
            darkMode = true;
            manualSunrise = "06:30";
            manualSunset = "18:30";
            matugenSchemeType = "scheme-fruit-salad";
            schedulingMode = "off";
            useWallpaperColors = true;
          };
          controlCenter = {
            cards = [
              {
                enabled = true;
                id = "profile-card";
              }
              {
                enabled = true;
                id = "shortcuts-card";
              }
              {
                enabled = true;
                id = "audio-card";
              }
              {
                enabled = true;
                id = "brightness-card";
              }
              {
                enabled = true;
                id = "weather-card";
              }
              {
                enabled = true;
                id = "media-sysmon-card";
              }
            ];
            diskPath = "/";
            position = "close_to_bar_button";
            shortcuts = {
              left = [
                {
                  id = "Network";
                }
                {
                  id = "Bluetooth";
                }
                {
                  id = "ScreenRecorder";
                }
                {
                  id = "WallpaperSelector";
                }
              ];
              right = [
                {
                  id = "Notifications";
                }
                {
                  id = "PowerProfile";
                }
                {
                  id = "KeepAwake";
                }
                {
                  id = "NightLight";
                }
              ];
            };
          };
          desktopWidgets = {
            enabled = false;
            gridSnap = false;
            monitorWidgets = [

            ];
          };
          dock = {
            enabled = false;
          };
          general = {
            allowPanelsOnScreenWithoutBar = true;
            animationDisabled = false;
            animationSpeed = 1;
            avatarImage = "${homeDir}/.face";
            boxRadiusRatio = 0.4;
            compactLockScreen = false;
            lockScreenAnimations = true;
            enableLockScreenMediaControls = true;
            dimmerOpacity = 0.2;
            enableShadows = true;
            forceBlackScreenCorners = false;
            iRadiusRatio = 0.3;
            language = "";
            lockOnSuspend = true;
            radiusRatio = 0.5;
            scaleRatio = 1;
            screenRadiusRatio = 0.5;
            shadowDirection = "bottom_right";
            shadowOffsetX = 1;
            shadowOffsetY = 2;
            showChangelogOnStartup = true;
            showHibernateOnLockScreen = false;
            showScreenCorners = false;
            showSessionButtonsOnLockScreen = true;
          };
          hooks = {
            darkModeChange = "";
            enabled = true;
            performanceModeDisabled = "";
            performanceModeEnabled = "";
            screenLock = "";
            screenUnlock = "";
            wallpaperChange = "";
          };
          location = {
            analogClockInCalendar = false;
            firstDayOfWeek = -1;
            hideWeatherCityName = false;
            hideWeatherTimezone = false;
            name = "Madrid";
            showCalendarEvents = true;
            showCalendarWeather = true;
            showWeekNumberInCalendar = false;
            use12hourFormat = false;
            useFahrenheit = false;
            weatherEnabled = true;
            weatherShowEffects = true;
          };
          network = {
            bluetoothDetailsViewMode = "grid";
            bluetoothHideUnnamedDevices = false;
            bluetoothRssiPollIntervalMs = 10000;
            bluetoothRssiPollingEnabled = false;
            wifiDetailsViewMode = "grid";
            wifiEnabled = true;
          };
          nightLight = {
            autoSchedule = true;
            dayTemp = "6500";
            enabled = false;
            forced = false;
            manualSunrise = "06:30";
            manualSunset = "18:30";
            nightTemp = "4000";
          };
          notifications = {
            backgroundOpacity = lib.mkForce 1;
            criticalUrgencyDuration = 15;
            enableKeyboardLayoutToast = true;
            enabled = true;
            location = "top_right";
            lowUrgencyDuration = 3;
            # Quickshell matches the connector name (not Hyprland's desc:), so
            # this pins toasts to the Dell S2716DG 1440p on Cerberus.
            monitors = [ "DP-3" ];
            normalUrgencyDuration = 8;
            overlayLayer = true;
            respectExpireTimeout = false;
            saveToHistory = {
              critical = true;
              low = true;
              normal = true;
            };
            sounds = {
              criticalSoundFile = "";
              enabled = false;
              excludedApps = "discord,firefox,chrome,chromium,edge";
              lowSoundFile = "";
              normalSoundFile = "";
              separateSounds = false;
              volume = 0.5;
            };
          };
          osd = {
            autoHideMs = 2000;
            backgroundOpacity = lib.mkForce 1;
            enabled = true;
            enabledTypes = [
              0
              1
              2
              4
            ];
            location = "top_right";
            monitors = [

            ];
            overlayLayer = true;
          };
          screenRecorder = {
            audioCodec = "opus";
            audioSource = "default_output";
            colorRange = "limited";
            copyToClipboard = false;
            directory = "${homeDir}/Videos";
            frameRate = 60;
            quality = "very_high";
            showCursor = true;
            videoCodec = "h264";
            videoSource = "portal";
          };
          sessionMenu = {
            countdownDuration = 10000;
            enableCountdown = true;
            largeButtonsLayout = "grid";
            largeButtonsStyle = false;
            position = "center";
            powerOptions = [
              {
                action = "lock";
                enabled = true;
              }
              {
                action = "suspend";
                enabled = true;
              }
              {
                action = "hibernate";
                enabled = true;
              }
              {
                action = "reboot";
                enabled = true;
              }
              {
                action = "logout";
                enabled = true;
              }
              {
                action = "shutdown";
                enabled = true;
              }
            ];
            showHeader = true;
            showNumberLabels = true;
          };
          settingsVersion = 37;
          systemMonitor = {
            cpuCriticalThreshold = 90;
            cpuPollingInterval = 3000;
            cpuWarningThreshold = 80;
            criticalColor = "";
            diskCriticalThreshold = 90;
            diskPollingInterval = 3000;
            diskWarningThreshold = 80;
            enableDgpuMonitoring = false;
            externalMonitor = "resources || missioncenter || jdsystemmonitor || corestats || system-monitoring-center || gnome-system-monitor || plasma-systemmonitor || mate-system-monitor || ukui-system-monitor || deepin-system-monitor || pantheon-system-monitor";
            gpuCriticalThreshold = 90;
            gpuPollingInterval = 3000;
            gpuWarningThreshold = 80;
            loadAvgPollingInterval = 3000;
            memCriticalThreshold = 90;
            memPollingInterval = 3000;
            memWarningThreshold = 80;
            networkPollingInterval = 3000;
            tempCriticalThreshold = 90;
            tempPollingInterval = 3000;
            tempWarningThreshold = 80;
            useCustomColors = false;
            warningColor = "";
          };
          templates = {
            alacritty = false;
            cava = false;
            code = false;
            discord = false;
            emacs = false;
            enableUserTemplates = false;
            foot = false;
            fuzzel = false;
            ghostty = false;
            gtk = false;
            helix = false;
            hyprland = false;
            kcolorscheme = false;
            kitty = false;
            mango = false;
            niri = false;
            pywalfox = false;
            qt = false;
            spicetify = false;
            telegram = false;
            vicinae = false;
            walker = false;
            wezterm = false;
            yazi = false;
            zed = false;
            zenBrowser = false;
          };
          ui = {
            bluetoothDetailsViewMode = "grid";
            bluetoothHideUnnamedDevices = false;
            boxBorderEnabled = true;
            fontDefault = lib.mkForce "Maple Mono NF";
            fontDefaultScale = lib.mkForce 1;
            fontFixed = lib.mkForce "monospace";
            fontFixedScale = 1;
            networkPanelView = "wifi";
            panelBackgroundOpacity = lib.mkForce 1;
            panelsAttachedToBar = true;
            settingsPanelMode = "attached";
            tooltipsEnabled = true;
            wifiDetailsViewMode = "grid";
          };
          wallpaper = {
            directory = "${inputs.wallpapers}";
            enableMultiMonitorDirectories = false;
            enabled = true;
            fillColor = "#000000";
            fillMode = "crop";
            hideWallpaperFilenames = false;
            monitorDirectories = [

            ];
            overviewEnabled = false;
            panelPosition = "follow_bar";
            randomEnabled = false;
            randomIntervalSec = 300;
            recursiveSearch = true;
            setWallpaperOnAllMonitors = true;
            solidColor = "#1a1a2e";
            transitionDuration = 1500;
            transitionEdgeSmoothness = 0.05;
            transitionType = "random";
            useSolidColor = false;
            useWallhaven = false;
            wallhavenApiKey = "";
            wallhavenCategories = "111";
            wallhavenOrder = "desc";
            wallhavenPurity = "100";
            wallhavenQuery = "";
            wallhavenRatios = "";
            wallhavenResolutionHeight = "";
            wallhavenResolutionMode = "atleast";
            wallhavenResolutionWidth = "";
            wallhavenSorting = "relevance";
            wallpaperChangeMode = "random";
          };
        };
      };
    }
  );
}
