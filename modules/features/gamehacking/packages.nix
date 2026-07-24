{ pkgs }:

with pkgs; [
  # ═══════════════════════════════════════════════
  # DISASSEMBLERS & REVERSE ENGINEERING
  # ═══════════════════════════════════════════════
  ghidra              # NSA's SRE framework — Saturn SH-2, PSP MIPS, PS1 MIPS, x86
  radare2             # CLI reversing — quick triage, scripting
  iaito               # radare2 GUI (cutter successor)
  gdb                 # GNU debugger — x86 Linux targets
  # pwndbg            # not in nixpkgs — install via gdbinit / pip if needed
  rizin               # radare2 fork, better scripting
  python3Packages.binwalk3  # Firmware/ROM carving

  # ═══════════════════════════════════════════════
  # ROM/ISO PATCHING & MANIPULATION
  # ═══════════════════════════════════════════════
  xdelta              # xdelta3 — most fan translation patches use this
  # flips             # BPS patcher (not in nixpkgs — use beat or build from source)
  # beat              # alternative BPS tool
  # ipsutils          # IPS patching (not in nixpkgs)
  cdrkit              # mkisofs, isoinfo — BIN/CUE manipulation
  cdrdao              # disc image tools

  # ═══════════════════════════════════════════════
  # EMULATORS WITH DEBUG CAPABILITIES
  # ═══════════════════════════════════════════════
  ppsspp              # PSP emulator — built-in debugger, memory viewer, disasm
  pcsx2               # PS2 emulator — debugger, EE/VU register view
  # rpcs3 temporarily dropped: fails to link against glew on current nixpkgs
  # (undefined reference to __glewXSwapIntervalEXT). Re-add once upstream fixes it.
  # rpcs3             # PS3 emulator — RSX debugger
  dolphin-emu         # GameCube/Wii — debug mode, memory breakpoints
  mgba                # GBA emulator — built-in debugger, memory viewer
  mednafen            # Multi-system (Saturn/PS1/NES/SNES/etc.) — debugger
  mame                # Arcade — debugger with disassembler

  # ═══════════════════════════════════════════════
  # WINE + WINDOWS DEBUGGING
  # ═══════════════════════════════════════════════
  wineWow64Packages.stable # Run x86 Windows binaries (Korean PC Lunar etc.)
  winetricks           # DLL overrides, debug flags
  protontricks         # Proton-specific winetricks for Steam games

  # ═══════════════════════════════════════════════
  # FILE ANALYSIS & FORENSICS
  # ═══════════════════════════════════════════════
  foremost             # File carving — extract assets from raw dumps
  exiftool             # Metadata extraction
  file                 # File type identification
  hexdump              # Hex viewer
  xxd                  # Hex dump / reverse
  binutils             # strings, objdump, nm — binary inspection

  # ═══════════════════════════════════════════════
  # SCRIPTING & AUTOMATION
  # ═══════════════════════════════════════════════
  (python3.withPackages (ps: with ps; [
    construct          # Binary data parsing (file format RE)
    capstone           # Disassembly engine (multi-arch)
    unicorn            # CPU emulation (scriptable sandbox for RE)
    keystone           # Assembly engine (patch building)
    # pyserial         # For hardware RE (not needed yet)
    lief               # Binary parsing / modification
  ]))

  # ═══════════════════════════════════════════════
  # ASSET EXTRACTION & CONVERSION
  # ═══════════════════════════════════════════════
  ffmpeg              # FMV extraction, audio conversion, muxing
  imagemagick         # Sprite sheet extraction, image format conversion

  # ═══════════════════════════════════════════════
  # DOCUMENTATION & ANALYSIS
  # ═══════════════════════════════════════════════
  graphviz            # Call graphs, state machine diagrams
  # doxygen           # API docs from RE annotations (optional)
]
