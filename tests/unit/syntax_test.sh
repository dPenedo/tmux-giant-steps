#!/bin/sh
# Syntax check for every script in the repo, in its own interpreter: POSIX
# sh for most, bash for ai-jump and the TPM bootstrap (they use associative
# arrays / BASH_SOURCE).

test_all_scripts_parse_cleanly() {
	sh_files="$PROJECT_ROOT/scripts/sessionizer $PROJECT_ROOT/scripts/lib/config.sh $PROJECT_ROOT/scripts/lib/preview.sh $PROJECT_ROOT/scripts/lib/git.sh"
	bash_files="$PROJECT_ROOT/scripts/ai-jump $PROJECT_ROOT/tmux-giant-steps.tmux"

	for f in $sh_files; do
		out=$(sh -n "$f" 2>&1) || fail "sh -n $f: $out"
	done
	for f in $bash_files; do
		out=$(bash -n "$f" 2>&1) || fail "bash -n $f: $out"
	done
}
