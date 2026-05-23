{ pkgs, jetbrains-mono ? pkgs.jetbrains-mono }:

pkgs.stdenv.mkDerivation {
  name = "kanagawa-grub-theme";
  nativeBuildInputs = [ pkgs.grub2 ];

  unpackPhase = "true";
  installPhase = "true";

  buildPhase = ''
    mkdir -p "$out"

    grub-mkfont -s 16 -o "$out/JetBrainsMono.pf2" \
      "${jetbrains-mono}/share/fonts/truetype/JetBrainsMono-Regular.ttf"

    cat > "$out/theme.txt" <<'EOF'
# Kanagawa Dragon — GRUB boot theme
title-text:   ""
desktop-color: "#181616"

+ label {
  top   = 8%
  left  = 0%
  width = 100%
  align = "center"
  text  = "LaCie Recovery Drive"
  font  = "JetBrainsMono Regular 20"
  color = "#7e9cd8"
}

+ boot_menu {
  left                = 20%
  width               = 60%
  top                 = 22%
  height              = 58%
  item_font           = "JetBrainsMono Regular 16"
  item_color          = "#c5c9c5"
  selected_item_color = "#e6c384"
  item_height         = 36
  item_padding        = 12
  item_spacing        = 2
  icon_width          = 0
  icon_height         = 0
  scrollbar           = false
}

+ label {
  id    = "__timeout__"
  top   = 90%
  left  = 0%
  width = 100%
  align = "center"
  font  = "JetBrainsMono Regular 14"
  color = "#727169"
  text  = "Booting in %d seconds"
}
EOF
  '';
}
