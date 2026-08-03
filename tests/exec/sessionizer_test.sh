#!/bin/sh
# Exercises scripts/sessionizer as a real subprocess (as tmux/fzf would),
# against the isolated tmux server and XDG_*_HOME from test_env_setup.
#
# Note on exit codes: --mark/--add-then-jump and direct path invocation end
# in switch_to -> "tmux attach-session" without a tty, which returns 1 even
# though the session was created fine (see CLAUDE.md). Those tests ignore
# the exit status and check the real effect via "tmux has-session".

test_help_shows_usage() {
	out=$(sh "$SCRIPTS/sessionizer" -h)
	assert_contains "Usage:" "$out"
}

test_list_includes_tmux_sessions() {
	test_env_setup
	tmux new-session -d -s proyecto -c "$TEST_TMPDIR"
	out=$(sh "$SCRIPTS/sessionizer" --list)
	assert_contains "[TMUX] proyecto" "$out"
	assert_contains "[TMUX] dummy" "$out"
}

test_list_includes_extra_path_entries() {
	test_env_setup
	mkdir -p "$TEST_TMPDIR/proj-a"
	tmux set-option -g @sessionizer-search-path "$TEST_TMPDIR/nada-aqui"
	tmux set-option -g @sessionizer-extra-path "$TEST_TMPDIR/proj-a"
	out=$(sh "$SCRIPTS/sessionizer" --list)
	assert_contains "$TEST_TMPDIR/proj-a" "$out"
}

test_list_search_path_respects_per_entry_depth() {
	test_env_setup
	mkdir -p "$TEST_TMPDIR/root/a/b"
	mkdir -p "$TEST_TMPDIR/root/c"
	tmux set-option -g @sessionizer-search-path "$TEST_TMPDIR/root:1"
	out=$(sh "$SCRIPTS/sessionizer" --list)
	assert_contains "$TEST_TMPDIR/root/a" "$out"
	assert_contains "$TEST_TMPDIR/root/c" "$out"
	assert_not_contains "$TEST_TMPDIR/root/a/b" "$out"
}

test_list_search_path_prunes_git_dirs() {
	test_env_setup
	mkdir -p "$TEST_TMPDIR/root/repo/.git/objects"
	tmux set-option -g @sessionizer-search-path "$TEST_TMPDIR/root:2"
	out=$(sh "$SCRIPTS/sessionizer" --list)
	assert_contains "$TEST_TMPDIR/root/repo" "$out"
	assert_not_contains ".git" "$out"
}

test_fzf_preview_plain_dir_lists_files() {
	test_env_setup
	mkdir -p "$TEST_TMPDIR/dirx"
	: >"$TEST_TMPDIR/dirx/archivo.txt"
	out=$(sh "$SCRIPTS/sessionizer" --fzf-preview "$TEST_TMPDIR/dirx")
	assert_contains "archivo.txt" "$out"
}

test_fzf_preview_tmux_session_shows_window_name() {
	test_env_setup
	tmux new-session -d -s conpre -c "$TEST_TMPDIR" -n miventana
	out=$(sh "$SCRIPTS/sessionizer" --fzf-preview "[TMUX] conpre")
	assert_contains "miventana" "$out"
}

test_kill_item_kills_the_session() {
	test_env_setup
	tmux new-session -d -s victima -c "$TEST_TMPDIR"
	sh "$SCRIPTS/sessionizer" --kill "[TMUX] victima"
	if tmux has-session -t "=victima" 2>/dev/null; then
		fail "session 'victima' should be dead"
	fi
}

test_kill_item_on_plain_dir_is_a_noop() {
	test_env_setup
	out=$(sh "$SCRIPTS/sessionizer" --kill "$TEST_TMPDIR" 2>&1)
	assert_eq "" "$out"
}

test_add_mark_appends_to_marks_file() {
	test_env_setup
	mkdir -p "$TEST_TMPDIR/myrepo"
	sh "$SCRIPTS/sessionizer" --add "$TEST_TMPDIR/myrepo"
	assert_contains "$TEST_TMPDIR/myrepo" "$(cat "$XDG_CONFIG_HOME/tmux-giant-steps/marks.conf")"
}

test_mark_jump_creates_and_attaches_session() {
	test_env_setup
	mkdir -p "$TEST_TMPDIR/myrepo"
	sh "$SCRIPTS/sessionizer" --add "$TEST_TMPDIR/myrepo"
	sh "$SCRIPTS/sessionizer" --mark 1 || true
	tmux has-session -t "=myrepo" 2>/dev/null || fail "--mark 1 did not create the 'myrepo' session"
}

test_mark_jump_on_empty_slot_is_a_noop() {
	test_env_setup
	out=$(sh "$SCRIPTS/sessionizer" --mark 9 2>&1)
	assert_eq "" "$out"
}

test_mark_jump_on_missing_dir_prunes_the_line() {
	test_env_setup
	mkdir -p "$TEST_TMPDIR/desaparecido"
	sh "$SCRIPTS/sessionizer" --add "$TEST_TMPDIR/desaparecido"
	rmdir "$TEST_TMPDIR/desaparecido"

	sh "$SCRIPTS/sessionizer" --mark 1 || true

	out=$(cat "$XDG_CONFIG_HOME/tmux-giant-steps/marks.conf")
	assert_not_contains "desaparecido" "$out"
	tmux has-session -t "=desaparecido" 2>/dev/null && fail "should not have created a session for a pruned mark"
	return 0
}

test_mark_jump_after_pruning_keeps_later_marks_addressable() {
	test_env_setup
	mkdir -p "$TEST_TMPDIR/fantasma" "$TEST_TMPDIR/superviviente"
	sh "$SCRIPTS/sessionizer" --add "$TEST_TMPDIR/fantasma"
	sh "$SCRIPTS/sessionizer" --add "$TEST_TMPDIR/superviviente"
	rmdir "$TEST_TMPDIR/fantasma"

	sh "$SCRIPTS/sessionizer" --mark 1 || true
	sh "$SCRIPTS/sessionizer" --mark 1 || true

	tmux has-session -t "=superviviente" 2>/dev/null || fail "mark 1 should now point at 'superviviente' after the prune shifted it up"
}

test_switch_session_by_path_uses_basename_with_dots_as_underscores() {
	test_env_setup
	mkdir -p "$TEST_TMPDIR/my.repo.v2"
	sh "$SCRIPTS/sessionizer" "$TEST_TMPDIR/my.repo.v2" || true
	tmux has-session -t "=my_repo_v2" 2>/dev/null || fail "the 'my_repo_v2' session was not created"
}

test_switch_session_hydrates_from_local_tmux_sessionizer_file() {
	test_env_setup
	mkdir -p "$TEST_TMPDIR/hydrated"
	printf 'touch %s/hydrated-marker\n' "$TEST_TMPDIR" >"$TEST_TMPDIR/hydrated/.tmux-sessionizer"
	sh "$SCRIPTS/sessionizer" "$TEST_TMPDIR/hydrated" || true
	wait_until 25 0.2 test -f "$TEST_TMPDIR/hydrated-marker" || fail ".tmux-sessionizer was not sourced"
}
