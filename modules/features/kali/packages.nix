{ pkgs }:
# Restricted-minimal Kali toolset. Seeded from the 80/20 of stock kali-linux-default;
# refine from ~/.bash_history of prior Kali use.
# Tools logged as "# missing:" are not in nixpkgs and need overlay packaging.
with pkgs;
[
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
  # missing: bloodhound (python collector packaged as bloodhound-py separately)

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
  # missing: set (social-engineer-toolkit)
  # missing: kali-whoami
]
