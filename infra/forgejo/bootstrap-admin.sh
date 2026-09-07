set -euo pipefail
umask 077
if [ "$#" != 2 ]; then echo 'Usage: bootstrap-admin USERNAME EMAIL' >&2; exit 2; fi
compose=/etc/forgejo/compose
# Never reset an existing administrator or print its credentials on a rerun.
if "$compose" exec -T -u 1000 forgejo forgejo --config /etc/gitea/app.ini admin user list --admin | tail -n +2 | grep -q '[^[:space:]]'; then
  echo 'An administrator already exists; leaving accounts unchanged.'
else
  "$compose" exec -T -u 1000 forgejo forgejo --config /etc/gitea/app.ini admin user create --admin \
    --username "$1" --email "$2" --random-password --random-password-length 32 \
    --must-change-password > /etc/forgejo/admin-credentials
  chmod 0600 /etc/forgejo/admin-credentials
  echo 'Temporary credentials saved in /etc/forgejo/admin-credentials (root only).'
fi
touch /etc/forgejo/admin-ready
