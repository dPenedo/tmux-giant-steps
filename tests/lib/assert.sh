#!/bin/sh
# Minimal assertions for tests/run. Each assert_* prints the failure reason
# to stderr and exits 1 from the test's subshell; the runner captures both
# to mark it FAIL.

assert_eq() {
	if [ "$1" != "$2" ]; then
		echo "  expected <$1>, got <$2> ${3:-}" >&2
		exit 1
	fi
}

assert_contains() {
	case "$2" in
	*"$1"*) return 0 ;;
	esac
	echo "  <$2> does not contain <$1> ${3:-}" >&2
	exit 1
}

assert_not_contains() {
	case "$2" in
	*"$1"*)
		echo "  <$2> contains <$1> but shouldn't ${3:-}" >&2
		exit 1
		;;
	esac
}

fail() {
	echo "  ${1:-failure}" >&2
	exit 1
}

# skip <reason>: reports the test as skipped (exit 77, see tests/run).
skip() {
	echo "  ${1:-skipped}" >&2
	exit 77
}
