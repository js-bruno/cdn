#!/usr/bin/env bash
#
# Bootstrap a CLEAN Debian VPS for the CDN service (native systemd, no Docker).
# The Caddy binary (with the webdav plugin) is built and pushed by GitHub
# Actions, so this script does NOT need Go/xcaddy on the VPS.
#
# Usage (as root, from the repo root):
#   sudo deploy/scripts/setup-server.sh
# Optional env:
#   DEPLOY_USER=deploy        user that will run rsync/ssh deploys
#   CDN_HOST=... ADMIN_HOST=... ACME_EMAIL=... ADMIN_USER=...
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPLOY_USER="${DEPLOY_USER:-deploy}"
DEPLOY_GROUP="cdn-deploy"
CONTENT_DIR="/srv/cdn"
CONF_DIR="/etc/caddy"
STAGE_DIR="/home/lacon/cdn"
DATA_DIR="/var/lib/caddy"

if [ "$(id -u)" -ne 0 ]; then
	echo "run as root (sudo $0)" >&2
	exit 1
fi

echo "==> packages"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
	ca-certificates curl rsync openssh-server ufw apache2-utils

echo "==> users and groups"
if ! getent group "$DEPLOY_GROUP" >/dev/null; then
	groupadd --system "$DEPLOY_GROUP"
fi
if ! id caddy >/dev/null 2>&1; then
	useradd --system --home "$DATA_DIR" --shell /usr/sbin/nologin --user-group caddy
fi
usermod -aG "$DEPLOY_GROUP" caddy

if id "$DEPLOY_USER" >/dev/null 2>&1; then
	usermod -aG "$DEPLOY_GROUP" "$DEPLOY_USER"
	echo "    added user '$DEPLOY_USER' to $DEPLOY_GROUP"
else
	echo "    NOTE: user '$DEPLOY_USER' does not exist yet."
	echo "          create it (adduser $DEPLOY_USER) or rerun with DEPLOY_USER=<you>"
fi

echo "==> directories"
install -d -m 2775 -o caddy -g "$DEPLOY_GROUP" "$CONTENT_DIR"
install -d -m 0755 -o caddy -g caddy "$DATA_DIR" "$DATA_DIR/.local/share" "$DATA_DIR/.config"
install -d -m 0755 -o root -g root "$CONF_DIR"
if id "$DEPLOY_USER" >/dev/null 2>&1; then
	install -d -m 0755 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$STAGE_DIR"
else
	install -d -m 0755 "$STAGE_DIR"
	echo "    NOTE: create '$STAGE_DIR' owned by the deploy user before CI"
fi

echo "==> systemd unit"
install -m 0644 -o root -g root "$REPO_DIR/deploy/systemd/caddy.service" /etc/systemd/system/caddy.service

echo "==> apply helper + sudoers"
install -m 0755 -o root -g root "$REPO_DIR/deploy/scripts/remote-apply.sh" /usr/local/bin/cdn-apply
install -m 0440 -o root -g root "$REPO_DIR/deploy/sudoers.d/cdn-deploy" /etc/sudoers.d/cdn-deploy
visudo -cf /etc/sudoers.d/cdn-deploy

echo "==> admin credentials ($CONF_DIR/cdn.env)"
if [ ! -f "$CONF_DIR/cdn.env" ]; then
	PASS="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | cut -c1-20)"
	HASH="$(htpasswd -bnBC 10 "" "$PASS" | tr -d ':\n')"
	umask 0077
	cat > "$CONF_DIR/cdn.env" <<EOF
CDN_HOST=${CDN_HOST:-cdn.thisdev.space}
ADMIN_HOST=${ADMIN_HOST:-admin.thisdev.space}
ACME_EMAIL=${ACME_EMAIL:-admin@thisdev.space}
ADMIN_USER=${ADMIN_USER:-admin}
ADMIN_PASSWORD_HASH=$HASH
EOF
	chown root:caddy "$CONF_DIR/cdn.env"
	chmod 0640 "$CONF_DIR/cdn.env"
	printf 'admin user: %s\nadmin password: %s\n' "${ADMIN_USER:-admin}" "$PASS" > /root/cdn-admin-credentials.txt
	chmod 0600 /root/cdn-admin-credentials.txt
	echo "    generated admin password: $PASS"
	echo "    (saved to /root/cdn-admin-credentials.txt)"
else
	echo "    $CONF_DIR/cdn.env already exists — leaving it as-is"
fi

echo "==> firewall"
ufw allow OpenSSH >/dev/null 2>&1 || true
ufw allow 80/tcp >/dev/null 2>&1 || true
ufw allow 443/tcp >/dev/null 2>&1 || true
ufw allow 443/udp >/dev/null 2>&1 || true
ufw --force enable

echo "==> systemd"
systemctl daemon-reload
systemctl enable caddy >/dev/null 2>&1 || true

cat <<EOF

bootstrap done.

Next (first deploy) — push to GitHub main; the workflow builds the binary,
copies caddy/Caddyfile/browse.html to $STAGE_DIR and runs cdn-apply.
Manual equivalent:
    rsync -avz ./caddy Caddyfile browse.html $DEPLOY_USER@<vps>:$STAGE_DIR/
    ssh $DEPLOY_USER@<vps> 'sudo /usr/local/bin/cdn-apply'

Then publish content (stays out of git):
    DEPLOY_HOST=$DEPLOY_USER@<vps> deploy/scripts/deploy-rsync.sh

DNS: create A records for cdn.thisdev.space and admin.thisdev.space -> <vps IP>
before the first HTTPS request (Caddy issues certs automatically).
EOF
