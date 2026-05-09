{ pkgs, profile ? "default" }:
# Kali toolset, tiered to mirror kali-linux-{default,large,everything}.
#
# Sources cross-referenced for nixpkgs availability:
#   - kali-tools-* metapackage manifests (extracted /usr/share/doc/kali-meta)
#   - github.com/ScopeCreep-zip/kalilix
#   - github.com/Athena-OS/athena-nix modules/pentesting
#
# Packaging gaps (need overlays / RFCs upstream):
#   set (social-engineer-toolkit), kali-whoami, joomscan, openvas-scanner,
#   spiderfoot, maltego (unfree + tarball), bloodhound (community-edition),
#   recon-ng (in nixpkgs as `recon-ng`? verify), wpscan (ruby; in nixpkgs).
let
  core = with pkgs; [
    # Recon
    nmap
    masscan
    whois
    dnsutils
    subfinder
    amass

    # Web
    sqlmap
    ffuf
    gobuster
    feroxbuster
    nikto
    wfuzz

    # Passwords
    hashcat
    john
    hydra

    # Wireless
    aircrack-ng
    wifite2
    bettercap

    # Exploitation
    metasploit
    exploitdb

    # Post-exploitation
    python3Packages.impacket
    evil-winrm

    # Sniffing / spoofing
    wireshark
    tcpdump
    responder

    # Reverse engineering
    ghidra
    radare2
    gdb

    # Misc
    proxychains
    netcat-openbsd
    socat
  ];

  large = core ++ (with pkgs; [
    # Web (extended)
    wpscan
    whatweb
    httpx
    nuclei
    dirb
    dirbuster
    wafw00f

    # Recon (extended)
    fierce
    dnsrecon
    dnsenum
    enum4linux
    enum4linux-ng
    assetfinder
    waybackurls

    # Exploitation / post-ex
    netexec
    powersploit
    chisel
    ligolo-ng

    # Forensics
    volatility3
    foremost
    sleuthkit
    binwalk
    ddrescue
    testdisk

    # Mobile
    apktool
    jadx

    # Vuln scan
    lynis

    # Sniffing
    ettercap
    mitmproxy
    dsniff

    # Passwords
    hashid
    hash-identifier
    cewl
    crunch
    medusa
    ncrack

    # OSINT
    theharvester
    photon

    # RE
    rizin
    # cutter — broken in current nixpkgs (Qt6 deprecation errors)
  ]);

  everything = large ++ (with pkgs; [
    # Bluetooth
    bluez
    bluez-tools

    # VoIP
    sipvicious

    # Mobile (extended)
    frida-tools

    # DB
    sqlitebrowser
    mariadb-client

    # Cloud / container
    trivy
    kube-hunter
    kube-bench

    # Fuzzing
    aflplusplus
    radamsa

    # Misc heavy
    burpsuite
    zap
  ]);

  selected = {
    inherit core large everything;
    default = core;
  }.${profile};
in
selected
