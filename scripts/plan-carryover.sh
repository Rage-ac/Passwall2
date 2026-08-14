#!/usr/bin/env bash
#
# Work out which architectures have to be carried over from the previous release, and which
# architectures the resulting deployment must therefore contain.
#
# Usage:
#   plan-carryover.sh --fresh <file> --previous <file> [--expected-out <file>]
#
#   --fresh         one architecture per line: built from the current upstream release
#   --previous      previous release asset names (passwall2_signed_apk_<arch>.zip), one per line
#   --expected-out  where to write the architectures the deployment must contain
#
# Prints "<arch> <asset-name>" for every architecture that has to be carried over.
#
# Upstream uploads its per-architecture zips over several hours. A build that runs in between
# must not drop the architectures that are not there yet, otherwise the published repository
# loses them and apk reports "unexpected end of file" for those users (issue #5).

set -euo pipefail

usage() {
	echo "usage: $(basename "$0") --fresh <file> --previous <file> [--expected-out <file>]" >&2
	exit 2
}

fresh_file=""
previous_file=""
expected_out=""

while [ $# -gt 0 ]; do
	case "$1" in
		--fresh) fresh_file=${2:-}; shift 2 ;;
		--previous) previous_file=${2:-}; shift 2 ;;
		--expected-out) expected_out=${2:-}; shift 2 ;;
		-h|--help) sed -n '2,18p' "$0"; exit 0 ;;
		*) usage ;;
	esac
done

[ -n "$fresh_file" ] && [ -n "$previous_file" ] || usage
[ -r "$fresh_file" ] || { echo "cannot read $fresh_file" >&2; exit 2; }
[ -r "$previous_file" ] || { echo "cannot read $previous_file" >&2; exit 2; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

grep -v '^[[:space:]]*$' "$fresh_file" | sort -u > "$work/fresh"

: > "$work/carry"
: > "$work/previous-arches"
while read -r asset; do
	case "$asset" in
		passwall2_signed_apk_*.zip) ;;
		*) continue ;;
	esac
	arch=${asset#passwall2_signed_apk_}
	arch=${arch%.zip}
	[ -n "$arch" ] || continue
	echo "$arch" >> "$work/previous-arches"
	# noarch is rebuilt from the standalone packages on every run, never carried over.
	[ "$arch" = "noarch" ] && continue
	grep -qxF "$arch" "$work/fresh" && continue
	grep -qxF "$arch" "$work/carry" && continue
	echo "$arch" >> "$work/carry"
	printf '%s %s\n' "$arch" "$asset"
done < "$previous_file"

if [ -n "$expected_out" ]; then
	{
		cat "$work/fresh"
		cat "$work/previous-arches"
		echo noarch
	} | sort -u > "$expected_out"
fi
