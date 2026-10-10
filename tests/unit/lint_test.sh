#!/bin/sh
# Runs shellcheck and shfmt over every script and test. They usually come from
# Mason (Neovim) rather than the system, so its bin dir is tried too; with
# neither around the test is skipped, not failed.

SHELL_FILES="scripts/sessionizer scripts/ai-jump scripts/lib/config.sh scripts/lib/preview.sh scripts/lib/git.sh tmux-giant-steps.tmux tests/run tests/lib/assert.sh tests/lib/harness.sh"

find_tool() {
	if command -v "$1" >/dev/null 2>&1; then
		command -v "$1"
	elif [ -x "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/bin/$1" ]; then
		printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/bin/$1"
	else
		return 1
	fi
}

test_shellcheck_is_clean() {
	tool=$(find_tool shellcheck) || skip "shellcheck not found (PATH or Mason)"
	cd "$PROJECT_ROOT" || fail "no project root"
	# shellcheck disable=SC2086 # word-splitting the file list is the point
	out=$("$tool" $SHELL_FILES tests/*/*_test.sh 2>&1) || fail "shellcheck:
$out"
}

test_shfmt_has_nothing_to_change() {
	tool=$(find_tool shfmt) || skip "shfmt not found (PATH or Mason)"
	cd "$PROJECT_ROOT" || fail "no project root"
	# shellcheck disable=SC2086
	out=$("$tool" -d $SHELL_FILES tests/*/*_test.sh 2>&1) || fail "shfmt -d (run shfmt -w on these):
$out"
}
