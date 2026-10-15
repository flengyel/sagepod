#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

case "${1:-}" in
  -h|--help)
    echo 'Usage: bin/fix-bind-mounts.sh'
    echo 'Repair all six SagePod mounts for the host user and container user 1000:1000.'
    exit 0 ;;
  '') ;;
  *) die "Unknown argument: $1" ;;
esac
[[ $# -le 1 ]] || die 'Unexpected extra arguments.'
require_rootless_podman
require_cmd setfacl
mkdir -p -- "${MOUNT_DIRS[@]}"

# In Podman's rootless namespace, uid 0 is the invoking host user. Grant that
# user an ACL before changing ownership so existing 0700 directories stay usable.
# No host accounts or sudo commands are needed. Preserve executable files.
podman unshare bash -s -- "${MOUNT_DIRS[@]}" <<'PERMISSIONS'
set -euo pipefail
for dir in "$@"; do
  printf 'Fixing permissions: %s\n' "$dir"
  setfacl -R -P -m 'u:0:rwX' -- "$dir"
  chown -hR 1000:1000 -- "$dir"
  chmod -R u+rwX,g+rwX,o-rwx -- "$dir"
  find "$dir" -type d -exec chmod g+s -- {} +
  find "$dir" -type d -exec setfacl \
    -m 'd:u::rwx,d:u:0:rwx,d:g::rwx,d:m::rwx,d:o::---' -- {} +
done
PERMISSIONS

for dir in "${MOUNT_DIRS[@]}"; do
  probe="$(mktemp "${dir}/.sagepod-host-check.XXXXXX")"
  rm -- "$probe"
done
echo 'All six mounts are writable from the host.'
