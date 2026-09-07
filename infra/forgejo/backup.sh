# Invoked with a fixed PATH by the NixOS module.
set -euo pipefail
umask 077
exec 9>/run/forgejo-backup.lock
flock -n 9
compose=/etc/forgejo/compose
was_running=0
if "$compose" ps --status running --services | grep -qx forgejo; then was_running=1; fi
restart() {
  result=$?
  trap - EXIT
  if [ "$was_running" = 1 ]; then
    "$compose" up -d --wait --wait-timeout 240 forgejo || result=1
  fi
  exit "$result"
}
trap restart EXIT
# Stop writers before taking either storage snapshot; leave PostgreSQL running.
"$compose" stop forgejo
"$compose" exec -T postgres sh -c 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
install -d -m 0700 /var/backups/forgejo
stamp=$(date -u +%Y%m%dT%H%M%SZ)
tmp=$(mktemp -d /var/backups/forgejo/.incomplete-XXXXXX)
"$compose" exec -T postgres sh -c 'pg_dump -Fc -U "$POSTGRES_USER" -d "$POSTGRES_DB"' > "$tmp/database.dump"
tar -czf "$tmp/files.tar.gz" -C /var/lib/forgejo data conf
cp /etc/forgejo/.env.tf "$tmp/env.tf"
cp /etc/forgejo/.env.local "$tmp/env.local"
cp -L /etc/forgejo/compose.yaml "$tmp/compose.yaml"
readlink /run/current-system > "$tmp/nixos-generation"
(cd "$tmp" && sha256sum database.dump files.tar.gz env.tf env.local compose.yaml nixos-generation > SHA256SUMS)
out=/var/backups/forgejo/forgejo-$stamp
# A timestamp collision must not nest a backup inside a previous one.
test ! -e "$out"
mv -T "$tmp" "$out"
# Only prune completed backups after this backup has succeeded; retain this one.
for old in /var/backups/forgejo/forgejo-*; do
  if [ "$old" != "$out" ] && [ -f "$old/SHA256SUMS" ]; then
    find "$old" -maxdepth 0 -mtime +14 -exec rm -rf -- {} +
  fi
done
printf 'Backup completed: %s\n' "$out"
