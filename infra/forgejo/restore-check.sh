# Restore a backup into an isolated Compose project. Never writes production data.
set -euo pipefail
umask 077
if [ "$#" != 2 ]; then echo 'Usage: restore-check BACKUP_DIRECTORY NEW_RESTORE_DIRECTORY' >&2; exit 2; fi
backup=$(realpath "$1")
restore=$(realpath -m "$2")
test -d "$backup"
test ! -e "$restore" || { echo 'Restore destination must not exist' >&2; exit 1; }
(cd "$backup" && sha256sum -c SHA256SUMS)
install -d -m 0700 "$restore"
cp "$backup"/env.tf "$backup"/env.local "$restore/"
tar -xzf "$backup/files.tar.gz" -C "$restore"
project=forgejo-restore-$(date +%s)-$$
docker compose -f "$backup/compose.yaml" --env-file "$restore/env.tf" --env-file "$restore/env.local" config --format json |
  jq --arg root "$restore" --arg project "$project" '
    .name = $project |
    del(.services.cloudflared) |
    del(.services.forgejo.ports) |
    .networks = {forgejo: {internal: true}} |
    .services[].networks = {forgejo: null} |
    .services[].restart = "no" |
    (.services[].volumes[] | select(.type == "bind") | .source) |= sub("^/var/lib/forgejo"; $root)
  ' > "$restore/compose.json"
compose() { docker compose -p "$project" -f "$restore/compose.json" "$@"; }
cleanup() {
  result=$?
  trap - EXIT
  compose down --remove-orphans || result=1
  exit "$result"
}
trap cleanup EXIT
compose up -d --wait --wait-timeout 180 postgres
compose exec -T postgres sh -c 'pg_restore --exit-on-error --no-owner -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < "$backup/database.dump"
compose up -d --wait --wait-timeout 240 forgejo
compose exec -T postgres sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c '\''SELECT count(*) AS users FROM "user"; SELECT count(*) AS repositories FROM repository;'\'''
compose exec -T -u 1000 forgejo sh -c 'test ! -d /var/lib/gitea/git/repositories || for owner in /var/lib/gitea/git/repositories/*; do for repo in "$owner"/*.git; do test ! -d "$repo" || git --git-dir="$repo" fsck --full || exit 1; done; done'
echo "Restore check passed; isolated files retained at $restore"
