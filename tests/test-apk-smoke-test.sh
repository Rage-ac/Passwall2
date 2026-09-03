#!/usr/bin/env bash
# Tests for scripts/apk-smoke-test.sh — resolving the apk client to run the end-to-end check with.
#
# The regression here: the script pinned apk-tools-static 3.0.7-r0, Alpine moved on to 3.0.8-r0,
# and from 2026-09-03 the daily watchdog failed on a 404 while the repository was in fact healthy.

set -uo pipefail
cd "$(dirname "$0")/.."
. tests/lib.sh

SCRIPT=scripts/apk-smoke-test.sh

pick() { bash "$SCRIPT" --pick-latest; }

echo "== apk-smoke-test.sh version resolution =="

out=$(printf '%s\n' \
	'<a href="apk-tools-static-3.0.7-r0.apk">apk-tools-static-3.0.7-r0.apk</a>' \
	'<a href="apk-tools-static-3.0.8-r0.apk">apk-tools-static-3.0.8-r0.apk</a>' | pick)
assert_eq "picks the newest build from a directory listing" "apk-tools-static-3.0.8-r0.apk" "$out"

out=$(printf '%s\n' apk-tools-static-3.0.8-r0.apk apk-tools-static-3.0.10-r0.apk | pick)
assert_eq "orders versions numerically, not lexically" "apk-tools-static-3.0.10-r0.apk" "$out"

out=$(printf '%s\n' apk-tools-static-3.0.8-r0.apk apk-tools-static-3.0.8-r2.apk | pick)
assert_eq "prefers the newer package revision" "apk-tools-static-3.0.8-r2.apk" "$out"

# apk-tools 2.x cannot read the ADB index we publish, so it must never be selected.
out=$(printf '%s\n' apk-tools-static-2.14.10-r0.apk | pick)
assert_eq "ignores apk-tools 2.x" "" "$out"

out=$(printf '%s\n' apk-tools-static-2.14.10-r0.apk apk-tools-static-3.0.8-r0.apk | pick)
assert_eq "picks 3.x when both generations are offered" "apk-tools-static-3.0.8-r0.apk" "$out"

out=$(printf '%s\n' 'nothing to see here' | pick)
assert_eq "reports nothing for an unrelated listing" "" "$out"

# The pin that broke the watchdog must not come back.
grep -q 'APK_VERSION:-}' "$SCRIPT"
assert_status "the client version is not hardcoded" 0 $?

finish
