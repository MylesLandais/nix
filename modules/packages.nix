{ pkgs }:

with pkgs;
[

  age
  ags
  argocd
  beads
  bind
  bitwarden-desktop
  btop
  bulletty
  cava
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
  chromium
  gamemode
  gcc
  gh
  git-lfs
  gnome-keyring
  gnome-secrets
  gnome-themes-extra
  grim
  gowall
  gpgme
  gtk-engine-murrine
  gum
  hack-font
  pkgs.maple-mono.NF-unhinted
  pkgs.maple-mono.truetype
  heroic
  hubble
  hyprshot
  jetbrains.idea-oss
  jetbrains-mono
  jq
  kanagawa-gtk-theme
  kanagawa-icon-theme
  kubernetes-helm
  lazygit
  libnotify
  liquidctl
  lmstudio
  mcp-k8s-go
  mcp-grafana
  mpv
  nitch
  nix-search-tv
  nixos-generators
  nwg-look
  obs-studio
  obsidian
  oci-cli
  opentofu
  opencloud-desktop
  pavucontrol
  playerctl
  pulseaudio
  pulseaudio-ctl
  pulsemixer
  protonup-rs
  python3
  revive
  ripgrep
  rustdesk
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
  tokyonight-gtk-theme
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
