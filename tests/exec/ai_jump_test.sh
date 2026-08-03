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
