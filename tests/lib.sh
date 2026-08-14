#!/usr/bin/env bash
# Minimal test helpers shared by the test scripts.

TESTS_RUN=0
TESTS_FAILED=0

pass() { TESTS_RUN=$((TESTS_RUN + 1)); printf 'ok   %s\n' "$1"; }
fail() {
	TESTS_RUN=$((TESTS_RUN + 1))
	TESTS_FAILED=$((TESTS_FAILED + 1))
	printf 'FAIL %s\n' "$1"
	[ $# -gt 1 ] && printf '     %s\n' "$2"
	return 0
}

assert_eq() { # <name> <expected> <actual>
	if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected '$2', got '$3'"; fi
}

assert_status() { # <name> <expected-status> <actual-status> [output]
	if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected exit $2, got $3${4:+ — $4}"; fi
}

assert_contains() { # <name> <needle> <haystack>
	case "$3" in
		*"$2"*) pass "$1" ;;
		*) fail "$1" "expected output to contain '$2', got: $3" ;;
	esac
}

finish() {
	printf -- '----\n%d test(s), %d failure(s)\n' "$TESTS_RUN" "$TESTS_FAILED"
	[ "$TESTS_FAILED" -eq 0 ]
}
