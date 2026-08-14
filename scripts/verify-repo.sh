#!/usr/bin/env bash
#
# Verify that an apk repository tree is complete and servable.
#
# Usage:
#   verify-repo.sh --dir <packages-dir>  [--expect <arch,arch,...|@file>] [--min-arch N] [--no-noarch]
#   verify-repo.sh --url <base-url>      --expect <arch,arch,...|@file>   [--min-arch N] [--no-noarch]
#
# --dir   validates a locally built tree (packages/<arch>/APKINDEX.tar.gz)
# --url   validates the published site, e.g. https://rage-ac.github.io/Passwall2/packages
# --expect  architectures that must be present; @file reads one architecture per line
#
# For every architecture the index must exist, be non-empty and start with the ADB magic that
# `apk mkndx` writes — that is what apk-tools v3 expects to find behind APKINDEX.tar.gz.
# Verified against a real apk-tools 3.0.7 client, these are the messages users get:
#   missing architecture directory (404)  -> "HTTP 404: Not Found"        (issue #3)
#   truncated or corrupt index            -> "unexpected end of file"     (issue #5)
#   signing key not installed             -> "UNTRUSTED signature"
# All three make the repository unusable, so the build has to fail before such a tree is deployed.

set -uo pipefail

INDEX_NAME="APKINDEX.tar.gz"
MIN_INDEX_BYTES="${MIN_INDEX_BYTES:-64}"

mode=""
target=""
expect_spec=""
min_arch=1
require_noarch=1

die() { echo "verify-repo: $*" >&2; exit 2; }

while [ $# -gt 0 ]; do
	case "$1" in
		--dir) mode=dir; target=${2:-}; shift 2 ;;
		--url) mode=url; target=${2:-}; shift 2 ;;
		--expect) expect_spec=${2:-}; shift 2 ;;
		--min-arch) min_arch=${2:-1}; shift 2 ;;
		--no-noarch) require_noarch=0; shift ;;
		-h|--help) sed -n '2,20p' "$0"; exit 0 ;;
		*) die "unknown argument: $1" ;;
	esac
done

[ -n "$mode" ] && [ -n "$target" ] || die "either --dir or --url is required"
[ "$mode" = "dir" ] || [ -n "$expect_spec" ] || die "--url requires --expect"

target=${target%/}

expected=()
if [ -n "$expect_spec" ]; then
	if [ "${expect_spec#@}" != "$expect_spec" ]; then
		file=${expect_spec#@}
		[ -r "$file" ] || die "cannot read expected-architecture file: $file"
		while read -r line; do
			[ -n "$line" ] && expected+=("$line")
		done < "$file"
	else
		IFS=, read -r -a expected <<< "$expect_spec"
	fi
fi

failures=0
checked=0
fail() { echo "FAIL  $*"; failures=$((failures + 1)); }
ok() { echo "ok    $*"; }

# Prints the size and the first four bytes (hex) of an index, or nothing when unavailable.
probe_index() {
	local arch=$1 size magic tmp
	if [ "$mode" = "dir" ]; then
		local path="$target/$arch/$INDEX_NAME"
		[ -f "$path" ] || return 1
		size=$(wc -c < "$path")
		magic=$(head -c 3 "$path")
	else
		tmp=$(mktemp)
		if ! curl -fsSL --retry 3 --retry-delay 5 --max-time 120 \
			-o "$tmp" "$target/$arch/$INDEX_NAME" 2>/dev/null; then
			rm -f "$tmp"
			return 1
		fi
		size=$(wc -c < "$tmp")
		magic=$(head -c 3 "$tmp")
		rm -f "$tmp"
	fi
	printf '%s\t%s\n' "$size" "$magic"
	return 0
}

check_arch() {
	local arch=$1 probe size magic
	checked=$((checked + 1))

	if ! probe=$(probe_index "$arch"); then
		fail "$arch: $INDEX_NAME is missing (apk would report 'HTTP 404: Not Found')"
		return
	fi
	size=${probe%%$'\t'*}
	magic=${probe#*$'\t'}

	if [ "$size" -lt "$MIN_INDEX_BYTES" ]; then
		fail "$arch: $INDEX_NAME is only ${size} bytes (truncated index)"
		return
	fi
	if [ "$magic" != "ADB" ]; then
		fail "$arch: $INDEX_NAME does not start with the ADB magic apk-tools v3 expects"
		return
	fi
	if [ "$mode" = "dir" ]; then
		local pkgs
		pkgs=$(find "$target/$arch" -maxdepth 1 -name '*.apk' | wc -l)
		if [ "$pkgs" -eq 0 ]; then
			fail "$arch: indexed directory contains no .apk packages"
			return
		fi
		ok "$arch: ${size} bytes index, ${pkgs} packages"
		return
	fi
	ok "$arch: ${size} bytes index"
}

if [ "$mode" = "dir" ]; then
	[ -d "$target" ] || die "not a directory: $target"
	present=()
	for dir in "$target"/*/; do
		[ -d "$dir" ] || continue
		present+=("$(basename "$dir")")
	done
	[ ${#present[@]} -gt 0 ] || die "no architecture directories under $target"

	# Everything that is published must be valid, plus everything that is expected must be published.
	for arch in "${present[@]}"; do check_arch "$arch"; done
	for arch in "${expected[@]:-}"; do
		[ -n "$arch" ] || continue
		found=0
		for p in "${present[@]}"; do [ "$p" = "$arch" ] && found=1 && break; done
		[ "$found" -eq 1 ] || fail "$arch: expected architecture is missing from the build"
	done
	arch_count=${#present[@]}
else
	for arch in "${expected[@]}"; do check_arch "$arch"; done
	arch_count=$checked
fi

if [ "$require_noarch" -eq 1 ]; then
	case " ${present[*]:-} ${expected[*]:-} " in
		*" noarch "*) ;;
		*) fail "noarch: architecture-independent directory is missing" ;;
	esac
fi

if [ "$arch_count" -lt "$min_arch" ]; then
	fail "repository has only $arch_count architectures (expected at least $min_arch)"
fi

echo "----"
echo "checked $checked architecture(s), $failures failure(s)"
[ "$failures" -eq 0 ] || exit 1
