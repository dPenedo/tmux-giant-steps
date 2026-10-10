#!/bin/sh
# Exercises scripts/ai-jump as a real subprocess (bash), against the
# isolated tmux server from test_env_setup.

test_help_shows_usage() {
	out=$(bash "$SCRIPTS/ai-jump" -h)
	assert_contains "Usage:" "$out"
}

test_list_no_match_returns_empty() {
	test_env_setup
	out=$(bash "$SCRIPTS/ai-jump" --list 'zzz-no-existe-este-patron-xyz')
	assert_eq "" "$out"
}

test_list_finds_process_running_as_child_of_pane_shell() {
	test_env_setup
	pane=$(tmux display-message -p '#{pane_id}')
	session=$(tmux display-message -p '#S')
	# Runs as a child of the pane's shell (doesn't replace it), like a
	# process inside a nested terminal: list_panes has to walk the pid tree,
	# not just check the pane's own pid.
	tmux send-keys -t "$pane" '(exec -a fake-claude sleep 30) & disown' C-m
	wait_until 25 0.2 sh -c "ps -eo args= | grep -qF fake-claude" ||
		fail "fake-claude process never showed up"
	out=$(bash "$SCRIPTS/ai-jump" --list 'claude')
	assert_contains "$session" "$out"
}

test_current_pane_is_listed_last() {
	test_env_setup
	first=$(tmux display-message -p '#{pane_id}')
	second=$(tmux split-window -d -P -F '#{pane_id}')
	for p in "$first" "$second"; do
		tmux send-keys -t "$p" '(exec -a fake-claude sleep 30) & disown' C-m
	done
	wait_until 25 0.2 sh -c "[ \$(ps -eo args= | grep -cF fake-claude) -ge 2 ]" ||
		fail "the two fake-claude processes never showed up"

	out=$(bash "$SCRIPTS/ai-jump" --from "$first" --list 'claude')
	assert_eq "$first" "$(printf '%s\n' "$out" | tail -1 | cut -f1)" "(--from $first)"
	# ...and it's the only row flagged with the "*" marker.
	assert_eq "1" "$(printf '%s\n' "$out" | cut -f4 | grep -c '^\*')" "(marker count)"
	assert_eq "$first" "$(printf '%s\n' "$out" | awk -F'\t' '$4 ~ /^\*/ {print $1}')" "(marked row)"

	out=$(bash "$SCRIPTS/ai-jump" --from "$second" --list 'claude')
	assert_eq "$second" "$(printf '%s\n' "$out" | tail -1 | cut -f1)" "(--from $second)"
}

test_list_without_origin_keeps_every_pane() {
	test_env_setup
	pane=$(tmux display-message -p '#{pane_id}')
	tmux send-keys -t "$pane" '(exec -a fake-claude sleep 30) & disown' C-m
	wait_until 25 0.2 sh -c "ps -eo args= | grep -qF fake-claude" ||
		fail "fake-claude process never showed up"
	# No --from and no $TMUX (test_env_setup unsets it): nothing to demote.
	out=$(bash "$SCRIPTS/ai-jump" --list 'claude')
	assert_contains "$pane" "$out"
}

test_preview_renders_pane_content() {
	test_env_setup
	pane=$(tmux display-message -p '#{pane_id}')
	# Marker split across two adjacent literals: same reason as
	# preview_test.sh, avoids tmux's echo of the typed command satisfying
	# wait_for_pane_text before the real output exists.
	tmux send-keys -t "$pane" "printf 'preview-mark''er\n'" C-m
	wait_for_pane_text "$pane" "preview-marker" || fail "pane never showed the marker"
	out=$(bash "$SCRIPTS/ai-jump" --preview "$pane")
	assert_contains "preview-marker" "$out"
}

test_state_option_colors_and_ranks_rows() {
	test_env_setup
	first=$(tmux display-message -p '#{pane_id}')
	second=$(tmux new-window -d -P -F '#{pane_id}')
	third=$(tmux new-window -d -P -F '#{pane_id}')
	for p in "$first" "$second" "$third"; do
		tmux send-keys -t "$p" '(exec -a fake-claude sleep 30) & disown' C-m
	done
	wait_until 25 0.2 sh -c "[ \$(ps -eo args= | grep -cF fake-claude) -ge 3 ]" ||
		fail "the three fake-claude processes never showed up"
	tmux set -g @ai-jump-state-option @agent_state
	tmux set -g @ai-jump-state-colors "waiting=1,done=2"
	tmux set -w -t "$second" @agent_state done
	tmux set -w -t "$third" @agent_state waiting

	out=$(bash "$SCRIPTS/ai-jump" --list 'claude')
	# waiting, then done, then the pane with no state.
	assert_eq "$third $second $first" "$(printf '%s\n' "$out" | cut -f1 | tr '\n' ' ' | sed 's/ $//')" "(order)"
	assert_contains "$(printf '\033[38;5;1m')" "$(printf '%s\n' "$out" | head -1)" "(waiting color)"
	assert_eq "0" "$(printf '%s\n' "$out" | tail -1 | grep -c "$(printf '\033')")" "(no state, no color)"
}

test_list_shows_repo_and_branch_of_the_pane() {
	test_env_setup
	make_repo "$TEST_TMPDIR/repo"
	git -C "$TEST_TMPDIR/repo" worktree add -q -b feat/y "$TEST_TMPDIR/repo-y"
	mkdir -p "$TEST_TMPDIR/repo-y/sub"
	tmux new-session -d -s enrama -c "$TEST_TMPDIR/repo-y/sub"
	tmux send-keys -t enrama '(exec -a fake-claude sleep 30) & disown' C-m
	wait_until 25 0.2 sh -c "ps -eo args= | grep -qF fake-claude" ||
		fail "fake-claude process never showed up"
	out=$(bash "$SCRIPTS/ai-jump" --list 'claude')
	assert_contains "repo [feat/y]" "$out"
}
