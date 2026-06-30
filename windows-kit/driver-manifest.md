# Driver manifest — Jerad's gaming build

Target hardware:
- **CPU:** AMD Ryzen 7 9850X3D (Granite Ridge, AM5)
- **Board:** ASUS TUF GAMING B850-E WIFI (AM5, B850)
- **GPU:** AMD Radeon RX 9070 XT
- **RAM:** Corsair Vengeance RGB 32 GB DDR5-6000 (EXPO)

Vendor CDNs (ASUS/AMD) sit behind JS + Cloudflare, so automated download is
unreliable. Treat this file as the source of truth: download manually into the
staging dir, then `fetch-driver-pack.sh` extracts/organizes the `.inf/.cat/.sys`
for offline use. **Install order on the machine: BIOS → chipset → GPU → rest.**

Staging layout (off-repo, e.g. `~/win-kit-staging/`):

```
Drivers/
  chipset/   AMD_Chipset_Software.exe
  gpu/       <Adrenalin>.exe  (or extracted .inf set)
  net/       Realtek_LAN/  MediaTek_WiFiBT/
  audio/     Realtek_Audio/
firmware/
  <ASUS BIOS .zip>     # -> build-firmware-usb.sh renames the .CAP to A5653.CAP
```

## BIOS / firmware (flash FIRST, via FlashBack — see build-firmware-usb.sh)
- **Source:** ASUS TUF GAMING B850-E WIFI support page → BIOS & Firmware.
- **FlashBack target filename:** `A5653.CAP` (board-specific; the renamer in the
  ASUS zip uses this — `build-firmware-usb.sh` does the rename for us).
- Flashing latest BIOS first guarantees current AGESA/microcode and stable EXPO
  for the DDR5-6000 kit before the OS goes on.

## Chipset (AMD B850/AM5) — post-install, NOT DISM-injected
The 3D V-Cache optimizer + core scheduler need the full chipset package; run it
as a post-install step rather than slipstreaming.
- **Source:** AMD → Chipset Drivers → AMD B850 (AM5).
- **Silent:** `AMD_Chipset_Software.exe /S /AcceptEULA`

## GPU (Radeon RX 9070 XT) — post-install
- **Source:** AMD → Radeon RX 9070 XT → Adrenalin Edition (latest WHQL).
- **Silent:** `Setup.exe -Install -S -AcceptEULA`

## Network — slipstream-friendly (.inf/.cat/.sys)
- **Realtek 2.5 GbE LAN** — ASUS support page (Realtek LAN driver).
- **MediaTek MT792x Wi-Fi 6E + Bluetooth** — ASUS support page (WiFi + BT).
- These are good candidates to inject so the box has network on first boot:
  - **Windows-side (real machine):**
    `dism /Image:C:\mount /Add-Driver /Driver:C:\Drivers\net /Recurse`
  - **Linux-side (this kit):** we cannot run DISM; instead place the extracted
    driver tree under `Drivers\` on the USB and either point autounattend
    `<DriverPaths>` at it, or drop it in a `$WinpeDriver$` folder at the USB root
    so Setup auto-loads it. `fetch-driver-pack.sh` extracts the trees for this.

## Audio (Realtek ALC) — post-install or slipstream
- **Source:** ASUS support page (Realtek Audio / "Audio" driver).
- Usually fine post-install; can be injected like the NIC drivers if desired.

## Notes
- `$WinpeDriver$` at the USB root = drivers auto-loaded during Windows PE/Setup.
- Keep the **GPU** and **chipset** as post-install `.exe` runs (their installers
  do more than drop `.inf`s); only inject NIC/audio if you want first-boot network.
- BIOS-update auto-pull was explicitly de-scoped to "manual/YOLO" — see the
  fetch script's printed URLs.
