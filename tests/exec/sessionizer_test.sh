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

test_list_marks_current_session_and_puts_it_last() {
	test_env_setup
	tmux set-option -g @sessionizer-search-path "$TEST_TMPDIR/nada-aqui"
	tmux new-session -d -s otra -c "$TEST_TMPDIR"
	# Run --list from inside a pane so the script sees a real $TMUX and can
	# resolve the current session (dummy).
	tmux send-keys -t dummy "sh '$SCRIPTS/sessionizer' --list >'$TEST_TMPDIR/list.txt'" C-m
	wait_until 25 0.2 test -s "$TEST_TMPDIR/list.txt" || fail "--list produced no output"

	out=$(cat "$TEST_TMPDIR/list.txt")
	assert_contains "* [TMUX] dummy" "$out"
	assert_contains "  [TMUX] otra" "$out"
	assert_eq "* [TMUX] dummy" "$(grep '\[TMUX\]' "$TEST_TMPDIR/list.txt" | tail -1 | cut -f1)" \
		"(the session you're in should sort last)"
}

test_marked_item_still_resolves() {
	test_env_setup
	mkdir -p "$TEST_TMPDIR/dirmarcado"
	: >"$TEST_TMPDIR/dirmarcado/archivo.txt"
	tmux new-session -d -s marcada -c "$TEST_TMPDIR"

	out=$(sh "$SCRIPTS/sessionizer" --fzf-preview "  $TEST_TMPDIR/dirmarcado")
	assert_contains "archivo.txt" "$out"

	sh "$SCRIPTS/sessionizer" --kill "* [TMUX] marcada"
	if tmux has-session -t "=marcada" 2>/dev/null; then
		fail "--kill should strip the marker and kill 'marcada'"
	fi
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

# --- git worktrees ---

# wt_repo_setup: $TEST_TMPDIR/repos/{repo,otro,repo-x}, repo-x being a
# linked worktree of repo on feat/x, with otro sorted between them by find.
wt_repo_setup() {
	test_env_setup
	TEST_TMPDIR=$(cd "$TEST_TMPDIR" && pwd -P)
	make_repo "$TEST_TMPDIR/repos/repo"
	mkdir -p "$TEST_TMPDIR/repos/otro"
	git -C "$TEST_TMPDIR/repos/repo" worktree add -q -b feat/x "$TEST_TMPDIR/repos/repo-x"
	tmux set-option -g @sessionizer-search-path "$TEST_TMPDIR/repos:1"
}

test_list_labels_checkouts_and_groups_worktrees_after_their_repo() {
	wt_repo_setup
	out=$(sh "$SCRIPTS/sessionizer" --list | grep -v '\[TMUX\]')
	assert_contains "[main]" "$(printf '%s\n' "$out" | grep "/repos/repo	")"
	assert_contains "[feat/x]" "$(printf '%s\n' "$out" | grep "/repos/repo-x	")"
	assert_eq "$TEST_TMPDIR/repos/repo-x" \
		"$(printf '%s\n' "$out" | grep -A1 "/repos/repo	" | tail -1 | cut -f1 | sed 's/^ *//')" \
		"(the worktree should follow its main checkout)"
	assert_not_contains "	" "$(printf '%s\n' "$out" | grep "/repos/otro")"
}

test_fzf_preview_git_dir_shows_branch_and_log() {
	wt_repo_setup
	out=$(sh "$SCRIPTS/sessionizer" --fzf-preview "$TEST_TMPDIR/repos/repo-x")
	assert_contains "[feat/x]" "$out"
	assert_contains "init" "$out"
}

test_new_worktree_creates_branch_dir_and_session() {
	wt_repo_setup
	printf 'feat/nueva\n\n' | sh "$SCRIPTS/sessionizer" --new-worktree "  $TEST_TMPDIR/repos/repo" >/dev/null || true
	[ -f "$TEST_TMPDIR/repos/repo-nueva/.git" ] || fail "worktree dir repo-nueva was not created"
	assert_eq "feat/nueva" "$(git -C "$TEST_TMPDIR/repos/repo-nueva" branch --show-current)"
	tmux has-session -t "=repo-nueva" 2>/dev/null || fail "no session for the new worktree"
}

test_new_worktree_checks_out_an_existing_branch_into_a_custom_dir() {
	wt_repo_setup
	git -C "$TEST_TMPDIR/repos/repo" branch ya-existe
	printf 'ya-existe\notro-nombre\n' | sh "$SCRIPTS/sessionizer" --new-worktree "$TEST_TMPDIR/repos/repo" >/dev/null || true
	assert_eq "ya-existe" "$(git -C "$TEST_TMPDIR/repos/otro-nombre" branch --show-current)"
}

test_new_worktree_with_empty_branch_does_nothing() {
	wt_repo_setup
	printf '\n' | sh "$SCRIPTS/sessionizer" --new-worktree "$TEST_TMPDIR/repos/repo" >/dev/null
	assert_eq "2" "$(git -C "$TEST_TMPDIR/repos/repo" worktree list | wc -l | tr -d ' ')"
}

test_remove_worktree_removes_clean_one_and_kills_its_session() {
	wt_repo_setup
	tmux new-session -d -s repo-x -c "$TEST_TMPDIR/repos/repo-x"
	printf 'repo-x\n\n' | sh "$SCRIPTS/sessionizer" --remove-worktree "  $TEST_TMPDIR/repos/repo-x" >/dev/null
	[ -e "$TEST_TMPDIR/repos/repo-x" ] && fail "repo-x should be gone"
	tmux has-session -t "=repo-x" 2>/dev/null && fail "the repo-x session should be dead"
	git -C "$TEST_TMPDIR/repos/repo" show-ref --verify --quiet refs/heads/feat/x || fail "the branch is kept unless you say y"
}

test_remove_worktree_needs_its_name_typed_back() {
	wt_repo_setup
	printf 'y\n\n' | sh "$SCRIPTS/sessionizer" --remove-worktree "$TEST_TMPDIR/repos/repo-x" >/dev/null
	[ -d "$TEST_TMPDIR/repos/repo-x" ] || fail "a y/yes must not be enough"
}

test_remove_worktree_refuses_with_uncommitted_changes() {
	wt_repo_setup
	: >"$TEST_TMPDIR/repos/repo-x/sucio.txt"
	printf 'repo-x\n\n' | sh "$SCRIPTS/sessionizer" --remove-worktree "$TEST_TMPDIR/repos/repo-x" >/dev/null 2>&1
	[ -f "$TEST_TMPDIR/repos/repo-x/sucio.txt" ] || fail "a dirty worktree must not be removed"
}

test_remove_worktree_ignores_the_main_checkout() {
	wt_repo_setup
	printf 'repo\ny\n\n' | sh "$SCRIPTS/sessionizer" --remove-worktree "$TEST_TMPDIR/repos/repo" >/dev/null
	[ -d "$TEST_TMPDIR/repos/repo/.git" ] || fail "the main checkout must never be removed"
}

test_remove_worktree_deletes_a_merged_branch_on_yes() {
	wt_repo_setup
	printf 'repo-x\ny\n' | sh "$SCRIPTS/sessionizer" --remove-worktree "$TEST_TMPDIR/repos/repo-x" >/dev/null
	git -C "$TEST_TMPDIR/repos/repo" show-ref --verify --quiet refs/heads/feat/x && fail "merged feat/x should be deleted after y"
	return 0
}

test_remove_worktree_never_deletes_an_unmerged_branch() {
	wt_repo_setup
	git -C "$TEST_TMPDIR/repos/repo-x" commit -q --allow-empty -m "solo en feat/x"
	printf 'repo-x\ny\ny\n' | sh "$SCRIPTS/sessionizer" --remove-worktree "$TEST_TMPDIR/repos/repo-x" >/dev/null
	[ -e "$TEST_TMPDIR/repos/repo-x" ] && fail "the (clean) worktree should be gone"
	git -C "$TEST_TMPDIR/repos/repo" show-ref --verify --quiet refs/heads/feat/x || fail "unmerged feat/x must be kept"
}

test_new_worktree_copies_and_symlinks_ignored_files() {
	wt_repo_setup
	printf 'SECRET=1\n' >"$TEST_TMPDIR/repos/repo/.env"
	mkdir -p "$TEST_TMPDIR/repos/repo/node_modules/pkg"
	tmux set-option -g @sessionizer-worktree-copy ".env,no-existe"
	tmux set-option -g @sessionizer-worktree-symlink "node_modules/"
	printf 'feat/semilla\n\n' | sh "$SCRIPTS/sessionizer" --new-worktree "$TEST_TMPDIR/repos/repo" >/dev/null || true
	wt="$TEST_TMPDIR/repos/repo-semilla"
	assert_eq "SECRET=1" "$(cat "$wt/.env")"
	[ -L "$wt/.env" ] && fail ".env should be a copy, not a link"
	[ -L "$wt/node_modules" ] || fail "node_modules should be a symlink"
	assert_eq "$TEST_TMPDIR/repos/repo/node_modules" "$(readlink "$wt/node_modules")"
	[ -e "$wt/no-existe" ] && fail "missing sources are skipped"
	return 0
}

test_list_worktrees_marks_the_current_one_last() {
	wt_repo_setup
	mkdir -p "$TEST_TMPDIR/repos/repo-x/sub"
	out=$(sh "$SCRIPTS/sessionizer" --list-worktrees "$TEST_TMPDIR/repos/repo-x/sub")
	assert_eq "2" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
	assert_contains "  $TEST_TMPDIR/repos/repo	" "$(printf '%s\n' "$out" | head -1)"
	assert_contains "* $TEST_TMPDIR/repos/repo-x	" "$(printf '%s\n' "$out" | tail -1)"
	assert_not_contains "otro" "$out"
}
