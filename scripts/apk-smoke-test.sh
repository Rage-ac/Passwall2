#!/usr/bin/env bash
#
# End-to-end check with a real apk-tools v3 client: set up a throwaway root exactly the way the
# README tells users to, point it at the published repository and make sure apk can update,
# trust the signature and resolve luci-app-passwall2.
#
# Usage:
#   apk-smoke-test.sh --url <base-url> --arch <arch> [--package <name>]
#
# Environment:
#   APK_STATIC   path to an existing apk.static binary (skips the download)
#
# Byte level checks cannot tell whether apk actually accepts what we publish — index format,
# signature trust and dependency resolution all have to work. This is the check that would have
# caught a repository that serves files but is unusable.

set -euo pipefail

APK_VERSION="${APK_VERSION:-3.0.7-r0}"
MIRRORS=(
	"https://dl-cdn.alpinelinux.org/alpine/edge/main/x86_64"
	"https://alpine.global.ssl.fastly.net/alpine/edge/main/x86_64"
	"https://mirror.leaseweb.com/alpine/edge/main/x86_64"
)

url=""
arch=""
package="luci-app-passwall2"

die() { echo "apk-smoke-test: $*" >&2; exit 2; }

while [ $# -gt 0 ]; do
	case "$1" in
		--url) url=${2:-}; shift 2 ;;
		--arch) arch=${2:-}; shift 2 ;;
		--package) package=${2:-}; shift 2 ;;
		-h|--help) sed -n '2,17p' "$0"; exit 0 ;;
		*) die "unknown argument: $1" ;;
	esac
done

[ -n "$url" ] && [ -n "$arch" ] || die "--url and --arch are required"
url=${url%/}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

apk_static=${APK_STATIC:-}
if [ -z "$apk_static" ]; then
	for mirror in "${MIRRORS[@]}"; do
		echo "Fetching apk-tools-static-$APK_VERSION from $mirror"
		if curl -fsSL --retry 2 --max-time 120 \
			-o "$work/apk-tools-static.apk" "$mirror/apk-tools-static-$APK_VERSION.apk"; then
			break
		fi
	done
	[ -f "$work/apk-tools-static.apk" ] || die "could not download apk-tools-static"
	tar xzf "$work/apk-tools-static.apk" -C "$work" sbin/apk.static 2>/dev/null
	apk_static="$work/sbin/apk.static"
	chmod +x "$apk_static"
fi

"$apk_static" --version

# apk-tools links its own TLS stack; point it at the distribution CA bundle.
if [ -z "${SSL_CERT_FILE:-}" ] && [ -r /etc/ssl/certs/ca-certificates.crt ]; then
	export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
	export SSL_CERT_DIR=/etc/ssl/certs
fi

root="$work/root"
mkdir -p "$root/etc/apk/keys" "$root/var/cache/apk"
echo "$arch" > "$root/etc/apk/arch"
echo "$url" > "$root/etc/apk/repositories"
curl -fsSL --retry 3 -o "$root/etc/apk/keys/passwall2-repo.rsa.pub" \
	"${url%/packages}/keys/passwall2-repo.rsa.pub" \
	|| die "cannot fetch the repository signing key"

"$apk_static" --root "$root" add --initdb --usermode >/dev/null 2>&1 || true

echo "=== apk update ($arch) ==="
if ! "$apk_static" --root "$root" update > "$work/update.log" 2>&1; then
	cat "$work/update.log"
	die "apk update failed"
fi
cat "$work/update.log"

grep -q "^OK:" "$work/update.log" || die "apk update did not report success"
if grep -qiE "untrusted|BAD signature" "$work/update.log"; then
	die "repository signature is not trusted"
fi

count=$(sed -n 's/^OK: \([0-9]*\) distinct packages available.*/\1/p' "$work/update.log")
[ -n "$count" ] && [ "$count" -gt 0 ] || die "apk sees no packages in the repository"
echo "apk sees $count packages for $arch"

# Note: installing would also need OpenWrt's own feeds (libc, luci, coreutils, ...), which this
# repository does not mirror, so resolution is verified against the index instead of a full solve.
echo "=== packages visible to apk ==="
if ! "$apk_static" --root "$root" list -a > "$work/list.log" 2>&1; then
	cat "$work/list.log"
	die "apk list failed"
fi
head -5 "$work/list.log"

grep -q "^${package}-" "$work/list.log" || die "$package is not in the index for $arch"
if [ "$arch" != "noarch" ]; then
	grep -qE "^[^ ]+ ${arch}( |\$)" "$work/list.log" \
		|| die "the index for $arch contains no package built for that architecture"
fi

echo "apk smoke test passed for $arch"
