#!/usr/bin/env bash
# Runs every test script. Requires bash, jq and coreutils; no other dependencies.
#
#   ./tests/run-tests.sh
#
# The live published repository is not touched here — use
#   scripts/verify-repo.sh --url https://rage-ac.github.io/Passwall2/packages --expect <arches>
# for that (the sync workflow does it after each deployment).

set -uo pipefail
cd "$(dirname "$0")/.."

command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }

failed=0
for t in tests/test-*.sh; do
	echo
	echo "### $t"
	bash "$t" || failed=1
done

echo
if [ "$failed" -eq 0 ]; then
	echo "all test suites passed"
else
	echo "test suites FAILED"
fi
exit "$failed"
