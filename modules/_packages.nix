{ pkgs }:

let
  eurostile-bold-extended = pkgs.callPackage ./fonts/_eurostile-bold-extended.nix { };
  chatgpt-linux = pkgs.callPackage ./_chatgpt-linux.nix { };
in
with pkgs;
[
  eurostile-bold-extended

  age
  ags
  argocd
  beads
  bind
  bitwarden-desktop
  blender
  btop
  bulletty
  cava
  chatgpt-linux
  cliphist
  code-cursor
  coreutils
  copilot-language-server
  # nemo and file-roller are managed by the gtk-mod feature (see modules/features/gtk/conf)
  cozy
  claude-code
  claude-monitor
  devenv
  dysk
  element-desktop
  exercism
  fastfetch
  fd
  ffmpeg
  firefox
  google-chrome
  chromium
  gamemode
  gcc
  gh
  gimp
  git-lfs
  gnome-keyring
  gnome-secrets
  gnome-themes-extra
  grim
  gowall
  gpgme
  # gtk-engine-murrine removed from nixpkgs (GTK2). It existed only to render
  # kanagawa-gtk-theme, which went with it; stylix generates the theme now.
  gum
  hack-font
  pkgs.maple-mono.NF-unhinted
  pkgs.maple-mono.truetype
  heroic
  hubble
  hyprshot
  # jetbrains.idea-oss dropped: nixpkgs marks it insecure (NIXPKGS-2026-2269) and
  # no longer updates it. Removed outright rather than swapped for jetbrains.idea.
  jetbrains-mono
  jq
  # kanagawa-gtk-theme removed from nixpkgs (GTK2 gtk-engine-murrine dependency);
  # stylix generates the widget theme from the Kanagawa base16Scheme instead.
  kanagawa-icon-theme
  krita
  kubernetes-helm
  lazygit
  libnotify
  liquidctl
  lmstudio
  mcp-k8s-go
  mcp-grafana
  nitch
  nix-search-tv
  nixos-generators
  nwg-look
  obs-studio
  obsidian
  oci-cli
  opentofu
  opencloud-desktop
  penpot-desktop
  pavucontrol
  playerctl
  pulseaudio
  pulseaudio-ctl
  pulsemixer
  protonup-rs
  python3
  revive
  ripgrep
  # TODO(unsolved): rustdesk dropped 2026-08-09. The nixpkgs bump changed one of its
  # dependencies, so 1.4.9 needed a fresh Rust+Flutter compile under a hash Hydra had
  # not published (404 in cache.nixos.org, chaotic and nix-community). Cargo fans out
  # inside each Nix job slot, so it drove load to 35 on a 12-core box even under
  # --max-jobs 4 --cores 3, and blew the 20-minute build budget.
  # This breaks `rustdesk-windows-qemu` (modules/flake-parts/bootstrap-apps.nix),
  # which shells out to the system rustdesk. windows-kit/install_rustdesk.ps1 is
  # unaffected — that installs on the Windows guest.
  # To restore: re-add once Hydra publishes a cached build for the current nixpkgs.
  virt-viewer
  sesh
  slack
  statix
  statping-ng
  teamspeak6-client
  telegram-desktop
  ayugram-desktop
  terraform-ls
  tflint
  tldr
  tmux
  # tokyonight-gtk-theme removed from nixpkgs (GTK2 gtk-engine-murrine), same as
  # kanagawa-gtk-theme above. The tokyonight flake input still themes everything else.
  treefmt
  upower
  unzip
  # windows-kit USB builders (scripts/write-windows-usb.sh, build-firmware-usb.sh,
  # fetch-driver-pack.sh). Heavy VM deps (qemu_full/OVMFFull/swtpm) come from the
  # `nix run .#test-windows-qemu` app instead.
  wimlib
  dosfstools
  mtools
  gptfdisk
  parted
  p7zip
  rsync
  # FOSS GRUB multiboot USB (scripts/setup-grub-multiboot-usb.sh)
  grub2_efi
  ntfs3g
  # vivaldi is provided via environment.systemPackages (vivaldiWithFlags in
  # modules/features/env-packages.nix) so it actually reads vivaldi-flags.conf.
  vesktop
  vial
  vulkan-tools
  wl-clipboard
  wlogout

]
