set -euo pipefail

program="iw4x-pack"

die() {
  echo "$program: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  iw4x-pack discover ROOT...
  iw4x-pack salvage SOURCE STAGING
  iw4x-pack create STAGING DEST [--mode auto|windows|nix|dual] [--parity-percent N]
  iw4x-pack verify PACK
  iw4x-pack repair PACK
  iw4x-pack restore PACK TARGET
  iw4x-pack import-runtime PACK
  iw4x-pack mirror PACK DEST

The tool only inventories and preserves files supplied by the user. It does not
download, authenticate, or establish the provenance of game data. Packs created
from salvaged data are marked unverified until independently validated.
EOF
}

require_directory() {
  local path="$1"
  [ -d "$path" ] || die "directory does not exist: $path"
}

require_pack() {
  local path="$1"
  require_directory "$path"
  [ -f "$path/manifest.json" ] || die "manifest.json is missing from pack: $path"
  [ -f "$path/inventory.json" ] || die "inventory.json is missing from pack: $path"
  [ -f "$path/BLAKE3SUMS" ] || die "BLAKE3SUMS is missing from pack: $path"
  [ -f "$path/recovery.par2" ] || die "recovery.par2 is missing from pack: $path"
}

canonical_missing() {
  realpath --canonicalize-missing -- "$1"
}

is_same_or_within() {
  local candidate="$1"
  local parent="$2"
  case "$candidate/" in
    "$parent/"*) return 0 ;;
    *) return 1 ;;
  esac
}

existing_parent() {
  local path="$1"
  while [ ! -e "$path" ]; do
    local parent
    parent="$(dirname -- "$path")"
    [ "$parent" != "$path" ] || break
    path="$parent"
  done
  printf '%s\n' "$path"
}

filesystem_type() {
  local probe
  probe="$(existing_parent "$1")"
  findmnt --noheadings --output FSTYPE --target "$probe" 2>/dev/null | head -n1
}

auto_mode_for_path() {
  local fs_type
  fs_type="$(filesystem_type "$1")"

  case "$fs_type" in
    ntfs | ntfs3 | fuseblk | exfat)
      printf '%s\n' dual
      ;;
    vfat)
      die "FAT32 cannot safely hold large IW4x pack files; use NTFS, exFAT, or a native Linux filesystem"
      ;;
    ext2 | ext3 | ext4 | btrfs | xfs | zfs)
      printf '%s\n' nix
      ;;
    cifs | nfs | nfs4 | fuse.gvfsd-fuse | "")
      die "cannot infer an archive mode for filesystem '$fs_type'; pass --mode windows, nix, or dual"
      ;;
    *)
      die "unsupported filesystem '$fs_type'; pass an explicit --mode"
      ;;
  esac
}

create_inventory() {
  local root="$1"
  local output="$2"
  local records
  records="$(mktemp)"

  while IFS= read -r -d '' file_path; do
    local relative size digest
    relative="${file_path#"$root"/}"
    size="$(stat --format=%s -- "$file_path")"
    digest="$(b3sum -- "$file_path" | cut -d' ' -f1)"
    jq --compact-output --null-input \
      --arg path "$relative" \
      --argjson size "$size" \
      --arg blake3 "$digest" \
      '{path: $path, size: $size, blake3: $blake3}' >> "$records"
  done < <(find "$root" -type f -print0 | sort --zero-terminated)

  jq --slurp '{schema_version: 1, files: .}' "$records" > "$output"
  rm -f -- "$records"
}

verify_inventory() {
  local root="$1"
  local inventory="$2"
  local failed=0

  while IFS= read -r encoded; do
    local record relative expected_size expected_digest file_path actual_size actual_digest
    record="$(printf '%s' "$encoded" | base64 --decode)"
    relative="$(jq --raw-output '.path' <<<"$record")"
    expected_size="$(jq --raw-output '.size' <<<"$record")"
    expected_digest="$(jq --raw-output '.blake3' <<<"$record")"
    file_path="$root/$relative"

    if [ ! -f "$file_path" ]; then
      echo "missing: $relative" >&2
      failed=1
      continue
    fi

    actual_size="$(stat --format=%s -- "$file_path")"
    actual_digest="$(b3sum -- "$file_path" | cut -d' ' -f1)"
    if [ "$actual_size" != "$expected_size" ] || [ "$actual_digest" != "$expected_digest" ]; then
      echo "mismatch: $relative" >&2
      failed=1
    fi
  done < <(jq --raw-output '.files[] | @base64' "$inventory")

  [ "$failed" -eq 0 ]
}

layout_report() {
  local root="$1"
  local report="$2"
  local missing=0

  {
    echo "IW4x/MW2 archive-only salvage report"
    echo "Generated: $(date --utc --iso-8601=seconds)"
    echo "Source status: unverified"
    echo
    for required in binkw32.dll mss32.dll iw4mp.exe; do
      if [ -f "$root/$required" ]; then
        echo "present: $required"
      else
        echo "missing: $required"
        missing=1
      fi
    done
    for required_dir in main zone; do
      if [ -d "$root/$required_dir" ]; then
        echo "present: $required_dir/"
      else
        echo "missing: $required_dir/"
        missing=1
      fi
    done
    echo
    if [ "$missing" -eq 0 ]; then
      echo "The expected layout is present, but file provenance and Steam integrity remain unverified."
    else
      echo "The candidate is incomplete and is not expected to launch without additional recovery."
    fi
  } > "$report"
}

discover() {
  [ "$#" -gt 0 ] || die "discover requires at least one root"

  local root
  for root in "$@"; do
    [ -e "$root" ] || {
      echo "unavailable root: $root" >&2
      continue
    }
    find "$root" \
      \( -type d -iname 'Call of Duty Modern Warfare 2' \
      -o -type f \( -iname '*iw4x*' -o -iname '*modern*warfare*2*' -o -iname '*mw2*' \
      -o -iname '*10190*' -o -iname 'iw4mp.exe' -o -iname 'iw4sp.exe' \) \) \
      -print 2>/dev/null || true
  done
}

salvage() {
  [ "$#" -eq 2 ] || die "salvage requires SOURCE and STAGING"
  local source="$1"
  local staging="$2"
  local copy_status=0

  [ -e "$source" ] || die "source does not exist: $source"
  [ ! -b "$source" ] || die "block-device recovery must use a separately approved ddrescue workflow"
  local source_real staging_real
  source_real="$(realpath -- "$source")"
  staging_real="$(canonical_missing "$staging")"
  if is_same_or_within "$staging_real" "$source_real"; then
    die "staging cannot be the source or a path inside it"
  fi
  if [ -e "$staging" ]; then
    [ -d "$staging" ] && [ -z "$(find "$staging" -mindepth 1 -print -quit)" ] \
      || die "staging target must be absent or empty: $staging"
  else
    mkdir -p -- "$staging"
  fi

  if [ -d "$source" ]; then
    if ! rsync --archive --partial --ignore-errors -- "$source/" "$staging/"; then
      copy_status=2
    fi
  elif [ -f "$source" ]; then
    if ! 7z t -- "$source"; then
      echo "archive integrity test reported errors; attempting best-effort extraction" >&2
      copy_status=2
    fi
    if ! 7z x -y -aos "-o$staging" -- "$source"; then
      copy_status=2
    fi
  fi

  layout_report "$staging" "$staging/salvage-report.txt"
  create_inventory "$staging" "$staging/salvage-inventory.json"
  echo "Salvaged data staged at: $staging"
  echo "Review: $staging/salvage-report.txt"

  if [ "$copy_status" -ne 0 ]; then
    echo "Salvage completed with read or extraction errors; partial data was preserved." >&2
  fi
  return "$copy_status"
}

create_pack() {
  [ "$#" -ge 2 ] || die "create requires STAGING and DEST"
  local source="$1"
  local destination="$2"
  shift 2

  local mode=auto
  local parity_percent=10
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --mode)
        [ "$#" -ge 2 ] || die "--mode requires a value"
        mode="$2"
        shift 2
        ;;
      --parity-percent)
        [ "$#" -ge 2 ] || die "--parity-percent requires a value"
        parity_percent="$2"
        shift 2
        ;;
      *) die "unknown create option: $1" ;;
    esac
  done

  require_directory "$source"
  [[ "$parity_percent" =~ ^[0-9]+$ ]] || die "parity percentage must be an integer"
  [ "$parity_percent" -ge 1 ] && [ "$parity_percent" -le 100 ] \
    || die "parity percentage must be between 1 and 100"

  local source_real destination_real
  source_real="$(realpath -- "$source")"
  destination_real="$(canonical_missing "$destination")"
  [ "$(filesystem_type "$destination_real")" != vfat ] \
    || die "FAT32 cannot safely hold large IW4x pack files; use NTFS, exFAT, or a native Linux filesystem"
  if is_same_or_within "$destination_real" "$source_real"; then
    die "destination cannot be the staged source or a path inside it"
  fi
  mkdir -p -- "$destination_real"

  if [ "$mode" = auto ]; then
    mode="$(auto_mode_for_path "$destination_real")"
  fi
  case "$mode" in windows | nix | dual) ;; *) die "invalid mode: $mode" ;; esac

  local stamp pack_name partial final
  stamp="$(date --utc +%Y%m%dT%H%M%SZ)"
  pack_name="iw4x-pack-$stamp-$mode"
  partial="$destination_real/.$pack_name.partial.$$"
  final="$destination_real/$pack_name"
  [ ! -e "$partial" ] && [ ! -e "$final" ] || die "pack destination already exists"
  mkdir -p -- "$partial"

  create_inventory "$source_real" "$partial/inventory.json"

  local -a payloads=()
  if [ "$mode" = windows ] || [ "$mode" = dual ]; then
    local windows_payload="$partial/game-data.zip"
    (
      cd "$source_real"
      7z a -tzip -mx=0 "$windows_payload" . >/dev/null
    )
    payloads+=("game-data.zip")
  fi

  if [ "$mode" = nix ] || [ "$mode" = dual ]; then
    tar --zstd --numeric-owner --create --file "$partial/game-data.tar.zst" --directory "$source_real" .
    payloads+=("game-data.tar.zst")

    [ -n "${IW4X_RUNTIME_CLOSURE_ROOT:-}" ] \
      || die "IW4X_RUNTIME_CLOSURE_ROOT was not supplied by the Nix package"
    local -a closure_paths=()
    mapfile -t closure_paths < <(nix-store --query --requisites "$IW4X_RUNTIME_CLOSURE_ROOT")
    nix-store --export "${closure_paths[@]}" \
      | zstd --threads=0 -10 --output="$partial/iw4x-runtime.nix-store.zst"
    printf '%s\n' "$IW4X_RUNTIME_CLOSURE_ROOT" > "$partial/runtime-root.txt"
    payloads+=("iw4x-runtime.nix-store.zst" "runtime-root.txt")

    cat > "$partial/import-runtime.sh" <<'IMPORT_RUNTIME_EOF'
#!/usr/bin/env bash
set -euo pipefail
pack_dir="$(cd "$(dirname "$0")" && pwd)"
zstd -dc "$pack_dir/iw4x-runtime.nix-store.zst" | nix-store --import
echo "Runtime root: $(cat "$pack_dir/runtime-root.txt")"
IMPORT_RUNTIME_EOF
    chmod 0755 "$partial/import-runtime.sh"
    payloads+=("import-runtime.sh")
  fi

  local payload_json
  payload_json="$(printf '%s\n' "${payloads[@]}" | jq --raw-input . | jq --slurp .)"
  jq --null-input \
    --arg created_at "$(date --utc --iso-8601=seconds)" \
    --arg mode "$mode" \
    --arg source_name "$(basename -- "$source_real")" \
    --arg launcher_version "${IW4X_LAUNCHER_VERSION:-unknown}" \
    --arg umu_version "${IW4X_UMU_VERSION:-unknown}" \
    --arg proton_version "${IW4X_PROTON_VERSION:-unknown}" \
    --argjson parity_percent "$parity_percent" \
    --argjson payloads "$payload_json" \
    '{
      schema_version: 1,
      kind: "archive-only-salvage",
      source_status: "unverified",
      created_at: $created_at,
      mode: $mode,
      source_name: $source_name,
      parity_percent: $parity_percent,
      payloads: $payloads,
      runtime: {
        launcher: $launcher_version,
        umu: $umu_version,
        proton: $proton_version
      }
    }' > "$partial/manifest.json"

  local -a protected_files=(manifest.json inventory.json "${payloads[@]}")
  (
    cd "$partial"
    b3sum -- "${protected_files[@]}" > BLAKE3SUMS
    par2 create -q "-r$parity_percent" recovery.par2 BLAKE3SUMS "${protected_files[@]}"
  )

  mv -- "$partial" "$final"
  echo "Created archive-only pack: $final"
}

verify_pack() {
  [ "$#" -eq 1 ] || die "verify requires PACK"
  local pack="$1"
  require_pack "$pack"
  local checksum_ok=0 parity_ok=0

  if (cd "$pack" && b3sum --check BLAKE3SUMS); then
    checksum_ok=1
  fi
  if (cd "$pack" && par2 verify -q recovery.par2); then
    parity_ok=1
  fi

  [ "$checksum_ok" -eq 1 ] && [ "$parity_ok" -eq 1 ] \
    || die "pack verification failed: $pack"
  echo "Verified pack: $pack"
}

repair_pack() {
  [ "$#" -eq 1 ] || die "repair requires PACK"
  local pack="$1"
  require_pack "$pack"
  (cd "$pack" && par2 repair -q recovery.par2)
  verify_pack "$pack"
}

restore_pack() {
  [ "$#" -eq 2 ] || die "restore requires PACK and TARGET"
  local pack="$1"
  local target="$2"
  require_pack "$pack"
  local pack_real target_real
  pack_real="$(realpath -- "$pack")"
  target_real="$(canonical_missing "$target")"
  if is_same_or_within "$target_real" "$pack_real"; then
    die "restore target cannot be the pack or a path inside it"
  fi
  verify_pack "$pack"

  if [ -e "$target" ]; then
    [ -d "$target" ] && [ -z "$(find "$target" -mindepth 1 -print -quit)" ] \
      || die "restore target must be absent or empty: $target"
  fi

  local parent staging mode payload
  parent="$(dirname -- "$target")"
  mkdir -p -- "$parent"
  staging="$target.iw4x-restore.$$"
  [ ! -e "$staging" ] || die "restore staging path already exists: $staging"
  mkdir -p -- "$staging"

  mode="$(jq --raw-output '.mode' "$pack/manifest.json")"
  case "$mode" in
    windows) payload="$pack/game-data.zip" ;;
    nix) payload="$pack/game-data.tar.zst" ;;
    dual)
      case "$(filesystem_type "$parent")" in
        ntfs | ntfs3 | fuseblk | exfat | vfat) payload="$pack/game-data.zip" ;;
        *) payload="$pack/game-data.tar.zst" ;;
      esac
      ;;
    *) die "unsupported pack mode in manifest: $mode" ;;
  esac

  case "$payload" in
    *.zip) unzip -q "$payload" -d "$staging" ;;
    *.tar.zst) tar --extract --file "$payload" --directory "$staging" ;;
    *) die "unsupported payload: $payload" ;;
  esac

  if ! verify_inventory "$staging" "$pack/inventory.json"; then
    die "restored files failed inventory verification; staging was preserved at $staging"
  fi

  if [ -d "$target" ]; then
    rmdir -- "$target"
  fi
  mv -- "$staging" "$target"
  echo "Restored and verified data at: $target"
}

import_runtime() {
  [ "$#" -eq 1 ] || die "import-runtime requires PACK"
  local pack="$1"
  require_pack "$pack"
  verify_pack "$pack"
  [ -f "$pack/iw4x-runtime.nix-store.zst" ] || die "pack does not contain a Nix runtime export"
  zstd --decompress --stdout "$pack/iw4x-runtime.nix-store.zst" | nix-store --import
  echo "Runtime root: $(cat "$pack/runtime-root.txt")"
}

mirror_pack() {
  [ "$#" -eq 2 ] || die "mirror requires PACK and DEST"
  local pack="$1"
  local destination="$2"
  require_pack "$pack"
  local pack_real destination_real
  pack_real="$(realpath -- "$pack")"
  destination_real="$(canonical_missing "$destination")"
  if is_same_or_within "$destination_real" "$pack_real"; then
    die "mirror destination cannot be the pack or a path inside it"
  fi
  verify_pack "$pack"
  mkdir -p -- "$destination_real"
  [ "$(filesystem_type "$destination_real")" != vfat ] \
    || die "FAT32 cannot safely hold large IW4x pack files; use NTFS, exFAT, or a native Linux filesystem"
  local target
  target="$destination_real/$(basename -- "$pack_real")"
  [ ! -e "$target" ] || die "mirror target already exists: $target"
  mkdir -p -- "$target"
  rsync --archive --partial --checksum -- "$pack/" "$target/"
  verify_pack "$target"
  echo "Mirrored pack: $target"
}

main() {
  [ "$#" -gt 0 ] || {
    usage
    exit 1
  }
  local command="$1"
  shift
  case "$command" in
    discover) discover "$@" ;;
    salvage) salvage "$@" ;;
    create) create_pack "$@" ;;
    verify) verify_pack "$@" ;;
    repair) repair_pack "$@" ;;
    restore) restore_pack "$@" ;;
    import-runtime) import_runtime "$@" ;;
    mirror) mirror_pack "$@" ;;
    -h | --help | help) usage ;;
    *) die "unknown command: $command" ;;
  esac
}

main "$@"
