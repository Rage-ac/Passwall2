#!/usr/bin/env bash
# Tests for scripts/check-update.sh — the gate that decides whether to rebuild the repository.
#
# The regression these tests exist for is issue #5: upstream had only 11 of its 13 architecture
# zips uploaded, the workflow built anyway, and the published repository lost
# arm_cortex-a7_neon-vfpv4 until upstream finished. apk then reported
# "unexpected end of file" for the missing architecture.

set -uo pipefail
cd "$(dirname "$0")/.."
. tests/lib.sh

SCRIPT=scripts/check-update.sh
NOW=1750000000	# fixed "current time" so age based rules are deterministic
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# upstream_json <tag> <arch-count> <age-hours>
upstream_json() {
	local tag=$1 count=$2 age_h=$3 published
	published=$(date -u -d "@$((NOW - age_h * 3600))" +%Y-%m-%dT%H:%M:%SZ)
	# Object values are parenthesised: jq 1.7 (what CI ships) rejects a bare "+" there.
	jq -n --arg tag "$tag" --arg published "$published" --argjson count "$count" '{
		tag_name: $tag,
		published_at: $published,
		assets: ([{name: ("luci-app-passwall2-" + $tag + ".apk")}]
			+ [range(0; $count) | {name: ("passwall_packages_apk_arch" + tostring + ".zip")}])
	}' > "$WORK/upstream.json"
	echo "$WORK/upstream.json"
}

# current_json <tag> <arch-count>   ("none" produces an empty payload)
current_json() {
	local tag=$1 count=${2:-0}
	if [ "$tag" = "none" ]; then
		echo '{}' > "$WORK/current.json"
	else
		jq -n --arg tag "$tag" --argjson count "$count" '{
			tag_name: $tag,
			assets: ([{name: "passwall2_signed_apk_noarch.zip"}]
				+ [range(0; $count) | {name: ("passwall2_signed_apk_arch" + tostring + ".zip")}])
		}' > "$WORK/current.json"
	fi
	echo "$WORK/current.json"
}

# manifest_json <tag> <fresh-count> <published-count>
manifest_json() {
	local tag=$1 fresh=$2 published=$3
	jq -n --arg tag "$tag" --argjson fresh "$fresh" --argjson published "$published" '{
		tag: $tag,
		fresh: [range(0; $fresh) | ("arch" + tostring)],
		arches: ([range(0; $published) | ("arch" + tostring)] + ["noarch"])
	}' > "$WORK/manifest.json"
	echo "$WORK/manifest.json"
}

# run_case <name> <expected> <utag> <ucount> <age> <ctag> <ccount> [manifest-file]
run_case() {
	local name=$1 expected=$2 utag=$3 ucount=$4 age=$5 ctag=$6 ccount=${7:-0} manifest=${8:-}
	local up cur out
	up=$(upstream_json "$utag" "$ucount" "$age")
	cur=$(current_json "$ctag" "$ccount")
	if [ -n "$manifest" ]; then
		out=$(bash "$SCRIPT" --upstream "$up" --current "$cur" --manifest "$manifest" --now "$NOW" 2>/dev/null)
	else
		out=$(bash "$SCRIPT" --upstream "$up" --current "$cur" --now "$NOW" 2>/dev/null)
	fi
	assert_eq "$name" "$expected" "$out"
}

echo "== check-update.sh =="

run_case "first build with no release of our own" \
	"update=true"  26.7.16-1 13 1  none

run_case "new upstream tag with the full set of architectures" \
	"update=true"  26.7.16-1 13 1  26.7.12-1 13

run_case "issue #5: new tag while upstream still uploading (11 < 13 published)" \
	"update=false" 26.7.16-1 11 1  26.7.12-1 13

run_case "issue #5 shape, but upstream release is past the grace period" \
	"update=true"  26.7.16-1 11 20 26.7.12-1 13

run_case "new tag with only the standalone luci packages uploaded" \
	"update=false" 26.7.16-1 0 0   26.7.12-1 13

run_case "new tag below the absolute floor even though we ship less" \
	"update=false" 26.7.16-1 5 1   26.7.12-1 3

run_case "new tag above the floor while we ship less" \
	"update=true"  26.7.16-1 12 1  26.7.12-1 3

run_case "same tag, upstream finished uploading after our build" \
	"update=true"  26.7.16-1 13 6  26.7.16-1 11

run_case "same tag, nothing changed" \
	"update=false" 26.8.14-1 13 40 26.8.14-1 13

run_case "same tag, upstream shrank (assets replaced) — no pointless rebuild" \
	"update=false" 26.8.14-1 11 2  26.8.14-1 13

echo "-- with a published manifest --"

# The published repository serves 13 architectures, but only 11 of them were built from the
# current tag; the other two were carried over. Counting release assets alone would conclude
# "nothing to do" and leave those two architectures on stale packages forever.
run_case "same tag, carried-over architectures are still pending a real build" \
	"update=true"  26.7.16-1 13 6  26.7.16-1 13 "$(manifest_json 26.7.16-1 11 13)"

run_case "same tag, manifest shows everything upstream has was built" \
	"update=false" 26.7.16-1 13 6  26.7.16-1 13 "$(manifest_json 26.7.16-1 13 13)"

# A manifest left over from an older deployment must not be trusted for the current tag.
run_case "manifest of a different tag is ignored" \
	"update=false" 26.8.14-1 13 40 26.8.14-1 13 "$(manifest_json 26.7.16-1 11 13)"

run_case "missing manifest file falls back to release assets" \
	"update=true"  26.7.16-1 13 6  26.7.16-1 11 "$WORK/no-such-manifest.json"

# Usage errors must be loud rather than silently allowing a build.
out=$(bash "$SCRIPT" 2>&1); assert_status "missing arguments exit 2" 2 $? "$out"
out=$(bash "$SCRIPT" --upstream "$WORK/nope.json" --current "$WORK/nope.json" 2>&1)
assert_status "unreadable input exits 2" 2 $? "$out"
echo '{}' > "$WORK/empty.json"
out=$(bash "$SCRIPT" --upstream "$WORK/empty.json" --current "$WORK/empty.json" 2>&1)
assert_status "upstream without tag exits 2" 2 $? "$out"

finish
