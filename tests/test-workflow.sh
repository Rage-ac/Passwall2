#!/usr/bin/env bash
# Structural tests for the sync workflow: the safeguards added after issue #5 must stay wired up.

set -uo pipefail
cd "$(dirname "$0")/.."
. tests/lib.sh

WF=.github/workflows/sync-passwall2.yml
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "== sync-passwall2.yml =="

[ -f "$WF" ] || { echo "workflow not found: $WF" >&2; exit 2; }

if python3 -c 'import yaml' 2>/dev/null; then
	python3 - "$WF" "$WORK" <<'PY'
import sys, yaml, os
wf, work = sys.argv[1], sys.argv[2]
doc = yaml.safe_load(open(wf))
steps = doc['jobs']['check-and-update']['steps']
with open(os.path.join(work, 'steps.txt'), 'w') as f:
    for s in steps:
        f.write('%s | %s\n' % (s.get('name') or '', s.get('uses') or ''))
for i, s in enumerate(steps):
    if 'run' in s:
        with open(os.path.join(work, 'run-%02d.sh' % i), 'w', newline='\n') as f:
            f.write(s['run'])
PY
	assert_status "workflow YAML parses" 0 $?

	for script in "$WORK"/run-*.sh; do
		[ -f "$script" ] || continue
		err=$(bash -n "$script" 2>&1)
		assert_status "shell syntax: $(basename "$script")" 0 $? "$err"
	done

	steps=$(cat "$WORK/steps.txt")
	verify_line=$(echo "$steps" | grep -n "Verify repository before deploying" | head -1 | cut -d: -f1)
	upload_line=$(echo "$steps" | grep -n "upload-pages-artifact" | head -1 | cut -d: -f1)
	deploy_line=$(echo "$steps" | grep -n "deploy-pages" | head -1 | cut -d: -f1)
	published_line=$(echo "$steps" | grep -n "Verify published repository" | head -1 | cut -d: -f1)

	if [ -n "$verify_line" ] && [ -n "$upload_line" ] && [ "$verify_line" -lt "$upload_line" ]; then
		pass "repository is verified before the Pages artifact is uploaded"
	else
		fail "repository is verified before the Pages artifact is uploaded" "steps: $(echo "$steps" | tr '\n' ' ')"
	fi

	if [ -n "$deploy_line" ] && [ -n "$published_line" ] && [ "$deploy_line" -lt "$published_line" ]; then
		pass "the live site is smoke tested after deployment"
	else
		fail "the live site is smoke tested after deployment" "steps: $(echo "$steps" | tr '\n' ' ')"
	fi
else
	echo "note: python3 with PyYAML unavailable, skipping YAML level checks" >&2
fi

grep -q 'scripts/check-update.sh' "$WF"
assert_status "update decision comes from scripts/check-update.sh" 0 $?

grep -q 'scripts/verify-repo.sh' "$WF"
assert_status "deployment is guarded by scripts/verify-repo.sh" 0 $?

grep -q 'fresh-arches.txt' "$WF"
assert_status "architectures built from the current tag are tracked" 0 $?

grep -q 'scripts/plan-carryover.sh' "$WF"
assert_status "architectures missing upstream are carried over from the previous release" 0 $?

grep -q '_site/packages/manifest.json' "$WF"
assert_status "the deployment publishes a manifest of what it serves" 0 $?

grep -q 'packages/manifest.json"' "$WF"
assert_status "the previous manifest is read back before deciding to rebuild" 0 $?

grep -q 'scripts/apk-smoke-test.sh' "$WF"
assert_status "a real apk client checks the deployment" 0 $?

grep -q 'scripts/apk-smoke-test.sh' .github/workflows/verify-published.yml
assert_status "the daily watchdog also runs the real apk client" 0 $?

# gitlab.alpinelinux.org answers 418 to CI runners, which broke every build from 2026-09-02.
grep -q 'github.com/alpinelinux/apk-tools' "$WF"
assert_status "apk-tools is cloned from the GitHub mirror" 0 $?

if grep -A2 'for remote in' "$WF" | grep -q 'gitlab.alpinelinux.org'; then
	pass "gitlab stays as a fallback remote"
else
	fail "gitlab stays as a fallback remote" "no gitlab remote in the clone loop"
fi

for script in scripts/check-update.sh scripts/verify-repo.sh scripts/plan-carryover.sh scripts/apk-smoke-test.sh; do
	err=$(bash -n "$script" 2>&1)
	assert_status "shell syntax: $script" 0 $? "$err"
done

finish
