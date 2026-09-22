#!/usr/bin/env bash
#
# Generate a bcrypt hash for ADMIN_PASSWORD_HASH.
# Usage: deploy/scripts/gen-hash.sh 'sua-senha'
#
set -euo pipefail

if [ "$#" -ne 1 ]; then
	echo "usage: $0 'senha'" >&2
	exit 1
fi

if command -v caddy >/dev/null 2>&1; then
	caddy hash-password --plaintext "$1"
elif command -v htpasswd >/dev/null 2>&1; then
	htpasswd -bnBC 10 "" "$1" | tr -d ':\n'
	echo
else
	echo "no caddy/htpasswd found. Options:" >&2
	echo "  docker run --rm caddy:2.11 caddy hash-password --plaintext '$1'" >&2
	echo "  htpasswd -bnBC 10 '' '$1' | tr -d ':\\n'" >&2
	exit 1
fi
