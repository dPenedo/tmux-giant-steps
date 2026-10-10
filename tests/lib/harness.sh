#!/bin/sh
# Isolated environment for tests needing a real tmux and/or their own config
# dirs: a tmux server whose socket lives under a scratch TMUX_TMPDIR (tmux's
# "default" socket var when no -L/-S is given, which is how both the plugin
# scripts and the bootstrap call tmux), plus scratch XDG_CONFIG_HOME/
# XDG_CACHE_HOME so tests never touch the user's real tmux or marks.conf.
# Cleanup (kill-server + rm -rf) runs in an EXIT trap, even on failure.
test_env_setup() {
	TEST_TMPDIR=$(mktemp -d)
	XDG_CONFIG_HOME="$TEST_TMPDIR/config"
	XDG_CACHE_HOME="$TEST_TMPDIR/cache"
	TMUX_TMPDIR="$TEST_TMPDIR/tmux"
	mkdir -p "$TMUX_TMPDIR"
	export XDG_CONFIG_HOME XDG_CACHE_HOME TMUX_TMPDIR
	unset TMUX
	trap 'tmux kill-server >/dev/null 2>&1 || true; rm -rf "$TEST_TMPDIR"' EXIT
	# The user's real login shell may have .zshrc/.bashrc hooks (e.g.
	# auto-attach) that would leak into test panes. default-command forces a
	# clean bash for every session on this isolated server, including ones
	# sessionizer creates when jumping to a mark.
	printf 'set -g default-command "bash --norc --noprofile"\n' >"$TEST_TMPDIR/tmux.conf"
	tmux -f "$TEST_TMPDIR/tmux.conf" new-session -d -s dummy -x 80 -y 24
}

# wait_for_pane_text <pane> <text> [tries=25] [interval=0.2]
# Polls capture-pane until <text> shows up or attempts run out — avoids a
# fixed sleep while waiting for send-keys output.
wait_for_pane_text() {
	pane="$1"
	needle="$2"
	tries="${3:-25}"
	interval="${4:-0.2}"
	i=0
	while [ "$i" -lt "$tries" ]; do
		case "$(tmux capture-pane -p -t "$pane" 2>/dev/null)" in
		*"$needle"*) return 0 ;;
		esac
		i=$((i + 1))
		sleep "$interval"
	done
	return 1
}

# wait_until <tries> <interval> <cmd...>: retries <cmd> until it succeeds or
# attempts run out.
wait_until() {
	tries="$1"
	interval="$2"
	shift 2
	i=0
	while [ "$i" -lt "$tries" ]; do
		"$@" && return 0
		i=$((i + 1))
		sleep "$interval"
	done
	return 1
}

# make_repo <dir>: a git repo on branch "main" with one empty commit. Global
# and system git config are ignored so the user's hooks/aliases can't leak in
# (exported, so the scripts under test see the same).
make_repo() {
	GIT_CONFIG_GLOBAL=/dev/null
	GIT_CONFIG_NOSYSTEM=1
	GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
	GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
	export GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
	git init -q -b main "$1"
	git -C "$1" commit -q --allow-empty -m init
}
