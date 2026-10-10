#!/bin/sh
# Unit tests for scripts/lib/git.sh, against throwaway repos (no tmux).

git_setup() {
	TEST_TMPDIR=$(mktemp -d)
	trap 'rm -rf "$TEST_TMPDIR"' EXIT
	. "$PROJECT_ROOT/scripts/lib/git.sh"
}

test_worktree_read_main_checkout() {
	git_setup
	make_repo "$TEST_TMPDIR/repo"
	worktree_read "$TEST_TMPDIR/repo" || fail "should detect the main checkout"
	assert_eq "main" "$wt_kind"
	assert_eq "$TEST_TMPDIR/repo" "$wt_main"
	assert_eq "main" "$wt_branch"
	assert_eq "[main]" "$wt_label"
}

test_worktree_read_linked_worktree() {
	git_setup
	make_repo "$TEST_TMPDIR/repo"
	git -C "$TEST_TMPDIR/repo" worktree add -q -b feat/x "$TEST_TMPDIR/repo-x"
	worktree_read "$TEST_TMPDIR/repo-x" || fail "should detect the linked worktree"
	assert_eq "linked" "$wt_kind"
	assert_eq "$(cd "$TEST_TMPDIR/repo" && pwd -P)" "$wt_main"
	assert_eq "feat/x" "$wt_branch"
	assert_contains "[feat/x]" "$wt_label"
	assert_contains " repo" "$wt_label"
}

test_worktree_read_detached_head() {
	git_setup
	make_repo "$TEST_TMPDIR/repo"
	git -C "$TEST_TMPDIR/repo" worktree add -q --detach "$TEST_TMPDIR/repo-d"
	worktree_read "$TEST_TMPDIR/repo-d" || fail "should detect the detached worktree"
	assert_eq "detached" "$wt_branch"
}

test_worktree_read_plain_dir_and_subdir_are_not_checkouts() {
	git_setup
	mkdir -p "$TEST_TMPDIR/plain"
	make_repo "$TEST_TMPDIR/repo"
	mkdir -p "$TEST_TMPDIR/repo/sub"
	worktree_read "$TEST_TMPDIR/plain" && fail "plain dir is not a checkout"
	worktree_read "$TEST_TMPDIR/repo/sub" && fail "a subdir is not the top of a checkout"
	return 0
}

test_find_worktree_root_walks_up_from_a_subdir() {
	git_setup
	make_repo "$TEST_TMPDIR/repo"
	mkdir -p "$TEST_TMPDIR/repo/a/b"
	assert_eq "$TEST_TMPDIR/repo" "$(find_worktree_root "$TEST_TMPDIR/repo/a/b")"
}

test_worktree_dir_for_branch_uses_last_segment() {
	git_setup
	assert_eq "/r/ardiketak-eguneko-esaera" "$(worktree_dir_for_branch /r/ardiketak feat/eguneko-esaera)"
	assert_eq "/r/empleo-cv" "$(worktree_dir_for_branch /r/empleo cv)"
}

test_repo_main_from_inside_a_linked_worktree() {
	git_setup
	make_repo "$TEST_TMPDIR/repo"
	git -C "$TEST_TMPDIR/repo" worktree add -q -b x "$TEST_TMPDIR/repo-x"
	mkdir -p "$TEST_TMPDIR/repo-x/sub"
	assert_eq "$(cd "$TEST_TMPDIR/repo" && pwd -P)" "$(repo_main "$TEST_TMPDIR/repo-x/sub")"
}
