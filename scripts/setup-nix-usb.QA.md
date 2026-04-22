# Nix USB QA Checklist

## Goal
Validate the Ventoy-first Nix recovery/config USB workflow:
- Ventoy boots staged ISOs
- `live_nix` provides persistent Linux-side workspace and repo storage
- `images` stores installer payloads
- `persistent_data` stores bulk cross-machine data

## Preflight
- Confirm target disk with `lsblk -o NAME,SIZE,MODEL,SERIAL,TRAN`
- Confirm the script is syntactically valid:
  - `bash -n ./scripts/setup-nix-usb.sh`
- Confirm required tools are available, or use:
  - `nix-shell -p parted ntfs3g exfatprogs dosfstools wget gnutar curl git rsync`

## Destructive Run
- Run:
  - `sudo ./scripts/setup-nix-usb.sh --device /dev/sdX --force-rebuild`
- Confirm `.nix-usb-logs/<timestamp>/` is created
- Confirm phases complete without error:
  - `prepare_tools`
  - `install_ventoy`
  - `resize_and_partition`
  - `format_partitions`
  - `mount_partitions`
  - `prepare_layout`
  - `stage_iso`
  - `sync_repo`
  - `validate_workspace`
  - `summarize_next_steps`

## Post-Run Disk Validation
- Run `lsblk -f /dev/sdX`
- Confirm labels/filesystems:
  - Ventoy partition is `exfat` labeled `Ventoy`
  - Ventoy EFI partition is `vfat` labeled `VTOYEFI`
  - Linux workspace partition is `ext4` labeled `live_nix`
  - images partition is `exfat` labeled `images`
  - bulk data partition is `ntfs` labeled `persistent_data`
- Run `blkid /dev/sdX1 /dev/sdX2 /dev/sdX3 /dev/sdX4 /dev/sdX5`

## Mount Validation
- Confirm mountpoints are active:
  - Ventoy mount exists and is writable
  - `live_nix` mount exists and is writable
  - `images` mount exists and is writable
  - `persistent_data` mount exists and is writable
- Create/remove a test file in each writable partition

## ISO Validation
- Confirm the staged NixOS ISO exists on the Ventoy partition
- Confirm the `.sha256` file exists if downloaded successfully
- Confirm rerunning the script without `--force-rebuild` does not redownload the ISO unnecessarily

## Repo Validation
- Confirm `${LIVE_NIX}/nix-configs` exists as a git checkout
- Run:
  - `git -C /mnt/nix-usb/live/nix-configs status`
  - `git -C /mnt/nix-usb/live/nix-configs branch --show-current`
- Confirm rerunning the script updates the repo with `git fetch` + `git pull --ff-only`

## Boot Validation
- Plug the LaCie into the target laptop
- Use the laptop boot menu to start Ventoy
- Confirm the staged NixOS ISO appears in the Ventoy menu
- Boot the NixOS ISO successfully
- From the live environment, mount `LABEL=live_nix` and confirm the repo and recovery directories are present

## Resume Validation
- Re-run the script without `--force-rebuild`
- Confirm disk phases are skipped when the layout is already correct
- Confirm mount, ISO, and repo phases behave predictably

## Failure Capture
- If a phase fails, record:
  - console output
  - corresponding log file from `.nix-usb-logs/<timestamp>/`
  - `lsblk -f`
  - `parted -s /dev/sdX unit MiB print`
