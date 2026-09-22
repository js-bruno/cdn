#!/usr/bin/env bash
#
# Publish local content/ to the VPS /srv/cdn (content stays OUT of git).
# Usage:
#   DEPLOY_HOST=deploy@1.2.3.4 deploy/scripts/deploy-rsync.sh [source-dir]
#
set -euo pipefail

SRC="${1:-content/}"
: "${DEPLOY_HOST:?defina DEPLOY_HOST (ex.: deploy@1.2.3.4)}"
PORT="${DEPLOY_PORT:-22}"

if [ ! -d "$SRC" ]; then
	echo "source '$SRC' does not exist (run cdn-seed to create content/)" >&2
	exit 1
fi

# No reload needed: file_server reads from disk on every request.
rsync -avz --delete --partial --info=progress2 \
	-e "ssh -p $PORT" \
	"$SRC" "$DEPLOY_HOST:/srv/cdn/"
