#!/usr/bin/env bash
#
# Decide whether the mirrored repository has to be rebuilt from the upstream release.
#
# Usage:
#   check-update.sh --upstream <release.json> --current <release.json>
#                   [--manifest <manifest.json>] [--now <epoch>]
#
#   --upstream   GitHub API payload of Openwrt-Passwall/openwrt-passwall2 latest release
#   --current    GitHub API payload of our own latest release ('{}' when we have none)
#   --manifest   packages/manifest.json of the currently published site, if it could be fetched
#   --now        current time as unix timestamp, for tests (default: now)
#
# Prints "update=true" or "update=false" on stdout (ready for $GITHUB_OUTPUT); all reasoning
# goes to stderr. Exits non-zero only on usage/parse errors.
#
# Upstream publishes a release in stages: the standalone luci .apk files appear first, the
# per-architecture zips trickle in over the following hours. Building from such a partial
# release used to replace the complete published repository with a smaller one, so users of
# the architectures that had not been uploaded yet got a 404 for their APKINDEX.tar.gz
# (issue #5: 13 architectures dropped to 11 and arm_cortex-a7_neon-vfpv4 disappeared).
# The rules below therefore never accept fewer architectures than we already publish, until
# the upstream release is old enough that the smaller set has to be intentional.

set -euo pipefail

MIN_ARCH="${MIN_ARCH:-10}"       # absolute floor: never publish a repository smaller than this
GRACE_HOURS="${GRACE_HOURS:-12}" # after this, a shrunken upstream release is taken at face value

usage() {
	echo "usage: $(basename "$0") --upstream <file> --current <file> [--manifest <file>] [--now <epoch>]" >&2
	exit 2
}

upstream_file=""
current_file=""
manifest_file=""
now=""

while [ $# -gt 0 ]; do
	case "$1" in
		--upstream) upstream_file=${2:-}; shift 2 ;;
		--current) current_file=${2:-}; shift 2 ;;
		--manifest) manifest_file=${2:-}; shift 2 ;;
		--now) now=${2:-}; shift 2 ;;
		-h|--help) sed -n '2,20p' "$0"; exit 0 ;;
		*) usage ;;
	esac
done

[ -n "$upstream_file" ] && [ -n "$current_file" ] || usage
now=${now:-$(date -u +%s)}

[ -r "$upstream_file" ] || { echo "cannot read $upstream_file" >&2; exit 2; }
[ -r "$current_file" ] || { echo "cannot read $current_file" >&2; exit 2; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

decide() {
	echo "update=$1"
	echo "$2" >&2
	exit 0
}

upstream_tag=$(jq -r '.tag_name // "none"' "$upstream_file")
current_tag=$(jq -r '.tag_name // "none"' "$current_file")

[ "$upstream_tag" != "none" ] || { echo "upstream release has no tag_name" >&2; exit 2; }

echo "Upstream tag: $upstream_tag" >&2
echo "Current tag: $current_tag" >&2

# No release of our own yet: nothing can regress, build whatever upstream has.
if [ "$current_tag" = "none" ]; then
	decide true "No current release present; will update"
fi

# Upstream ships one passwall_packages_apk_<arch>.zip per architecture; our release mirrors that
# as passwall2_signed_apk_<arch>.zip (plus the synthesized _noarch.zip, which is not a real
# architecture and is excluded everywhere below).
jq -r '.assets[]?.name | select(startswith("passwall_packages_apk_") and endswith(".zip"))
	| ltrimstr("passwall_packages_apk_") | rtrimstr(".zip")' "$upstream_file" | sort -u > "$work/upstream-arches"
jq -r '.assets[]?.name | select(startswith("passwall2_signed_apk_") and endswith(".zip"))
	| ltrimstr("passwall2_signed_apk_") | rtrimstr(".zip") | select(. != "noarch")' "$current_file" \
	| sort -u > "$work/published-arches"

# Architectures actually built from the current tag. The published set can be larger: it also
# contains architectures carried over from an earlier release while upstream was still uploading.
if [ -n "$manifest_file" ] && [ -r "$manifest_file" ] \
	&& [ "$(jq -r '.tag // "none"' "$manifest_file" 2>/dev/null)" = "$current_tag" ]; then
	jq -r '.fresh[]? | select(. != "noarch")' "$manifest_file" | sort -u > "$work/built-arches"
	echo "Using published manifest for the architectures built from $current_tag" >&2
else
	cp "$work/published-arches" "$work/built-arches"
fi

upstream_count=$(wc -l < "$work/upstream-arches")
published_count=$(wc -l < "$work/published-arches")
built_count=$(wc -l < "$work/built-arches")

echo "Upstream architectures: $upstream_count, published: $published_count, built from current tag: $built_count" >&2

upstream_published=$(jq -r '.published_at // empty' "$upstream_file")
if [ -n "$upstream_published" ]; then
	upstream_age_h=$(( (now - $(date -u -d "$upstream_published" +%s)) / 3600 ))
else
	upstream_age_h=$GRACE_HOURS
fi

required=$MIN_ARCH
if [ "$upstream_age_h" -lt "$GRACE_HOURS" ] && [ "$published_count" -gt "$required" ]; then
	required=$published_count
fi
echo "Upstream release age: ${upstream_age_h}h; required architectures: $required" >&2

if [ "$upstream_tag" != "$current_tag" ]; then
	if [ "$upstream_count" -lt "$required" ]; then
		decide false "Deferring new release $upstream_tag; upstream has only $upstream_count architectures (< $required)"
	fi
	decide true "Tag changed: $upstream_tag (was $current_tag); will update"
fi

# Same tag: rebuild when upstream published an architecture we have not built from this tag yet
# (upstream finishes uploading after our cron tick).
missing=$(comm -23 "$work/upstream-arches" "$work/built-arches" | tr '\n' ' ')
if [ -n "${missing// /}" ]; then
	decide true "Upstream grew under same tag; not built yet: ${missing% }"
fi

decide false "Already up to date"
