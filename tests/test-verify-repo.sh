#!/usr/bin/env bash
# Tests for scripts/verify-repo.sh — the guard that refuses to deploy an incomplete repository.

set -uo pipefail
cd "$(dirname "$0")/.."
. tests/lib.sh

SCRIPT=scripts/verify-repo.sh
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# make_arch <tree> <arch> [index-kind]
#   index-kind: valid (default) | missing | truncated | wrong-magic | no-packages
make_arch() {
	local tree=$1 arch=$2 kind=${3:-valid}
	local dir="$tree/$arch"
	mkdir -p "$dir"
	[ "$kind" = "no-packages" ] || printf 'fake package payload' > "$dir/example-1.0-r1.apk"
	case "$kind" in
		missing) ;;
		truncated) printf 'ADBd' > "$dir/APKINDEX.tar.gz" ;;
		wrong-magic) { printf '\037\213\010'; head -c 200 /dev/zero; } > "$dir/APKINDEX.tar.gz" ;;
		*) { printf 'ADBd'; head -c 200 /dev/zero; } > "$dir/APKINDEX.tar.gz" ;;
	esac
}

# new_tree <name> -> path of a fresh tree containing noarch plus two architectures
new_tree() {
	local tree="$WORK/$1"
	rm -rf "$tree"; mkdir -p "$tree"
	make_arch "$tree" noarch
	make_arch "$tree" aarch64_generic
	make_arch "$tree" arm_cortex-a7_neon-vfpv4
	echo "$tree"
}

echo "== verify-repo.sh =="

tree=$(new_tree complete)
out=$(bash "$SCRIPT" --dir "$tree" 2>&1)
assert_status "complete tree passes" 0 $? "$out"

out=$(bash "$SCRIPT" --dir "$tree" --expect "aarch64_generic,arm_cortex-a7_neon-vfpv4,noarch" 2>&1)
assert_status "complete tree satisfies an explicit expectation" 0 $? "$out"

# The exact issue #5 shape: the architecture is simply not part of the build any more.
tree=$(new_tree dropped-arch)
rm -rf "$tree/arm_cortex-a7_neon-vfpv4"
out=$(bash "$SCRIPT" --dir "$tree" --expect "aarch64_generic,arm_cortex-a7_neon-vfpv4,noarch" 2>&1)
assert_status "architecture dropped from the build fails" 1 $? "$out"
assert_contains "dropped architecture is named" "arm_cortex-a7_neon-vfpv4" "$out"

tree=$(new_tree missing-index)
make_arch "$tree" mips_24kc missing
out=$(bash "$SCRIPT" --dir "$tree" 2>&1)
assert_status "missing APKINDEX fails" 1 $? "$out"
assert_contains "missing index is reported" "is missing" "$out"

tree=$(new_tree truncated-index)
make_arch "$tree" mips_24kc truncated
out=$(bash "$SCRIPT" --dir "$tree" 2>&1)
assert_status "truncated APKINDEX fails" 1 $? "$out"
assert_contains "truncated index is reported" "truncated index" "$out"

tree=$(new_tree wrong-magic)
make_arch "$tree" mips_24kc wrong-magic
out=$(bash "$SCRIPT" --dir "$tree" 2>&1)
assert_status "index without ADB magic fails" 1 $? "$out"
assert_contains "wrong magic is reported" "ADB magic" "$out"

tree=$(new_tree empty-arch)
make_arch "$tree" mips_24kc no-packages
out=$(bash "$SCRIPT" --dir "$tree" 2>&1)
assert_status "architecture without packages fails" 1 $? "$out"

tree=$(new_tree no-noarch)
rm -rf "$tree/noarch"
out=$(bash "$SCRIPT" --dir "$tree" 2>&1)
assert_status "missing noarch fails" 1 $? "$out"
out=$(bash "$SCRIPT" --dir "$tree" --no-noarch 2>&1)
assert_status "missing noarch is accepted with --no-noarch" 0 $? "$out"

tree=$(new_tree too-few)
out=$(bash "$SCRIPT" --dir "$tree" --min-arch 10 2>&1)
assert_status "fewer architectures than --min-arch fails" 1 $? "$out"
assert_contains "architecture count is reported" "only 3 architectures" "$out"

out=$(bash "$SCRIPT" --dir "$WORK/does-not-exist" 2>&1)
assert_status "unknown directory exits 2" 2 $? "$out"
out=$(bash "$SCRIPT" --url https://example.invalid/packages 2>&1)
assert_status "--url without --expect exits 2" 2 $? "$out"

# @file form of --expect, as used by the workflow.
tree=$(new_tree expect-file)
printf 'aarch64_generic\narm_cortex-a7_neon-vfpv4\nmips_24kc\n' > "$WORK/expect.txt"
out=$(bash "$SCRIPT" --dir "$tree" --expect "@$WORK/expect.txt" 2>&1)
assert_status "expectation file lists a missing architecture" 1 $? "$out"
assert_contains "missing architecture from file is named" "mips_24kc" "$out"

finish
