#!/usr/bin/env bash
# Tests for scripts/plan-carryover.sh — which architectures survive a partial upstream upload.

set -uo pipefail
cd "$(dirname "$0")/.."
. tests/lib.sh

SCRIPT=scripts/plan-carryover.sh
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fresh() { printf '%s\n' "$@" > "$WORK/fresh.txt"; }
previous() { printf '%s\n' "$@" > "$WORK/previous.txt"; }
plan() { bash "$SCRIPT" --fresh "$WORK/fresh.txt" --previous "$WORK/previous.txt" --expected-out "$WORK/expected.txt"; }

echo "== plan-carryover.sh =="

# The issue #5 situation: upstream published 11 of its 13 architectures for the new tag.
fresh aarch64_generic arm_cortex-a7
previous passwall2_signed_apk_aarch64_generic.zip \
	passwall2_signed_apk_arm_cortex-a7.zip \
	passwall2_signed_apk_arm_cortex-a7_neon-vfpv4.zip \
	passwall2_signed_apk_noarch.zip
out=$(plan)
assert_eq "architecture missing from this build is carried over" \
	"arm_cortex-a7_neon-vfpv4 passwall2_signed_apk_arm_cortex-a7_neon-vfpv4.zip" "$out"
assert_eq "expected set is the union plus noarch" \
	"aarch64_generic arm_cortex-a7 arm_cortex-a7_neon-vfpv4 noarch" \
	"$(tr '\n' ' ' < "$WORK/expected.txt" | sed 's/ $//')"

# Complete build: nothing to carry over.
fresh aarch64_generic arm_cortex-a7
previous passwall2_signed_apk_aarch64_generic.zip passwall2_signed_apk_arm_cortex-a7.zip passwall2_signed_apk_noarch.zip
out=$(plan)
assert_eq "complete build carries nothing over" "" "$out"
assert_eq "expected set equals the build plus noarch" \
	"aarch64_generic arm_cortex-a7 noarch" \
	"$(tr '\n' ' ' < "$WORK/expected.txt" | sed 's/ $//')"

# noarch is rebuilt every run from the standalone luci packages, never carried over.
fresh aarch64_generic
previous passwall2_signed_apk_noarch.zip
out=$(plan)
assert_eq "noarch is never carried over" "" "$out"

# First deployment: no previous release at all.
fresh aarch64_generic arm_cortex-a7
previous ""
out=$(plan)
assert_eq "empty previous release carries nothing over" "" "$out"
assert_eq "expected set falls back to this build" \
	"aarch64_generic arm_cortex-a7 noarch" \
	"$(tr '\n' ' ' < "$WORK/expected.txt" | sed 's/ $//')"

# Unrelated assets (upstream zips, checksums, notes) must be ignored.
fresh aarch64_generic
previous passwall2_signed_apk_mips_24kc.zip passwall_packages_apk_x86_64.zip release-notes.md \
	passwall2_signed_apk_mips_24kc.zip
out=$(plan)
assert_eq "unrelated assets are ignored and duplicates collapsed" \
	"mips_24kc passwall2_signed_apk_mips_24kc.zip" "$out"

out=$(bash "$SCRIPT" --fresh "$WORK/fresh.txt" 2>&1); assert_status "missing --previous exits 2" 2 $? "$out"
out=$(bash "$SCRIPT" --fresh "$WORK/nope" --previous "$WORK/nope" 2>&1); assert_status "unreadable input exits 2" 2 $? "$out"

finish
