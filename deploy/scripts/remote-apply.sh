#!/usr/bin/env bash
#
# Installed on the VPS as /usr/local/bin/cdn-apply (root, via sudo).
# Applies the staged code in /home/lacon/cdn (binary + Caddyfile + browse.html)
# and (re)loads the caddy systemd service. Only CODE is deployed here — content
# lives in /srv/cdn and arrives via rsync/upload.
#
set -euo pipefail

STAGE_DIR="${STAGE_DIR:-/home/lacon/cdn}"
BIN_SRC="$STAGE_DIR/caddy"
BIN_DST="/usr/local/bin/caddy"
CONF_DIR="/etc/caddy"
CONTENT_DIR="/srv/cdn"
ENV_FILE="$CONF_DIR/cdn.env"
APPLY_DST="/usr/local/bin/cdn-apply"

log() { printf '%s\n' "$*"; }

if [ "$(id -u)" -ne 0 ]; then
	echo "cdn-apply: must run as root (use: sudo /usr/local/bin/cdn-apply)" >&2
	exit 1
fi

bin_changed=0
if [ -f "$BIN_SRC" ]; then
	if ! cmp -s "$BIN_SRC" "$BIN_DST"; then
		bin_changed=1
	fi
	install -m 0755 -o root -g root "$BIN_SRC" "$BIN_DST"
	log "cdn-apply: installed caddy binary"
elif [ ! -x "$BIN_DST" ]; then
	echo "cdn-apply: no binary staged at $BIN_SRC and none installed at $BIN_DST" >&2
	exit 1
fi

install -d -m 0755 -o root -g root "$CONF_DIR"
install -m 0644 -o root -g root "$STAGE_DIR/Caddyfile" "$CONF_DIR/Caddyfile"
install -m 0644 -o root -g root "$STAGE_DIR/browse.html" "$CONF_DIR/browse.html"
log "cdn-apply: installed Caddyfile + browse.html"

if [ ! -f "$ENV_FILE" ]; then
	umask 0077
	cat > "$ENV_FILE" <<'EOF'
CDN_HOST=cdn.thisdev.space
ADMIN_HOST=admin.thisdev.space
ACME_EMAIL=admin@thisdev.space
ADMIN_USER=admin
ADMIN_PASSWORD_HASH=CHANGE_ME
EOF
	chown root:caddy "$ENV_FILE"
	chmod 0640 "$ENV_FILE"
	log "cdn-apply: WARNING created $ENV_FILE with placeholder — set ADMIN_PASSWORD_HASH"
fi

# content dir owned by caddy with the deploy group (setgid) so both can write
install -d -m 2775 -o caddy -g cdn-deploy "$CONTENT_DIR"

systemctl daemon-reload
systemctl enable caddy >/dev/null 2>&1 || true

if [ "$bin_changed" -eq 1 ]; then
	systemctl restart caddy
else
	systemctl reload caddy 2>/dev/null || systemctl restart caddy
fi
log "cdn-apply: caddy -> $(systemctl is-active caddy || true)"

# self-update the applied helper if a newer one was staged
if [ -f "$STAGE_DIR/deploy/scripts/remote-apply.sh" ] && ! cmp -s "$STAGE_DIR/deploy/scripts/remote-apply.sh" "$APPLY_DST"; then
	install -m 0755 -o root -g root "$STAGE_DIR/deploy/scripts/remote-apply.sh" "$APPLY_DST"
	log "cdn-apply: updated $APPLY_DST"
fi
