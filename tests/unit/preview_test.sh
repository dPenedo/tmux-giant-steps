#!/bin/sh
# Unit tests for scripts/lib/preview.sh (render_pane). Needs a real tmux
# pane to capture, hence test_env_setup, but tests the library function
# directly rather than the sessionizer/ai-jump CLI.
#
# Markers sent via send-keys are split across two adjacent literals (e.g.
# 'marker-w''s'): tmux echoes the typed command before running it, and an
# unsplit marker would let wait_for_pane_text match that echo instead of the
# real output. The shell concatenates the literals at runtime (valid
# syntax), so the full marker only ever appears in the actual output.

test_render_pane_strips_trailing_whitespace() {
	test_env_setup
	. "$PROJECT_ROOT/scripts/lib/preview.sh"
	pane=$(tmux display-message -p '#{pane_id}')
	tmux send-keys -t "$pane" "printf 'marker-w''s   \n'" C-m
	wait_for_pane_text "$pane" "marker-ws" || fail "pane never showed the marker"
	line=$(render_pane "$pane" 20 | grep -F 'marker-ws')
	assert_eq "marker-ws" "$line"
}

test_render_pane_strips_trailing_sgr_codes() {
	test_env_setup
	. "$PROJECT_ROOT/scripts/lib/preview.sh"
	pane=$(tmux display-message -p '#{pane_id}')
	tmux send-keys -t "$pane" 'printf "marker-sg""r\033[0m\033[0m\n"' C-m
	wait_for_pane_text "$pane" "marker-sgr" || fail "pane never showed the marker"
	line=$(render_pane "$pane" 20 | grep -F 'marker-sgr')
	case "$line" in
	*"$(printf '\033')"*) fail "SGR codes were left untrimmed: $(printf '%s' "$line" | cat -v)" ;;
	esac
	assert_eq "marker-sgr" "$line"
}

test_render_pane_rejoins_wrapped_lines() {
	test_env_setup
	. "$PROJECT_ROOT/scripts/lib/preview.sh"
	pane=$(tmux display-message -p '#{pane_id}')
	long=$(awk 'BEGIN { for (i = 0; i < 100; i++) printf "x" }')
	tmux send-keys -t "$pane" "printf '${long}EN''D\n'" C-m
	wait_for_pane_text "$pane" "END" || fail "pane never showed the marker"
	joined=$(render_pane "$pane" 20 | grep -F 'END')
	assert_contains "${long}END" "$joined"
}
