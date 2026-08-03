#!/bin/sh
# Exercises tmux-giant-steps.tmux (TPM bootstrap) for real via
# "tmux run-shell" against the isolated server, checking binds with
# "tmux list-keys".

session_binding() {
	# session_binding <table> <key>: the list-keys line for that key, or
	# empty if unbound. Anchors on whitespace to avoid matching substrings
	# of other keys (e.g. "f" inside "find").
	tmux list-keys -T "$1" | grep -E "^bind-key[[:space:]]+(-r[[:space:]]+)?-T $1 ${2}([[:space:]]|\$)" || true
}

test_default_bindings_registered() {
	test_env_setup
	tmux run-shell "$PROJECT_ROOT/tmux-giant-steps.tmux"
	prefix=$(tmux list-keys -T prefix)
	assert_contains "$PROJECT_ROOT/scripts/sessionizer --edit" "$prefix"
	assert_contains "$PROJECT_ROOT/scripts/sessionizer --add" "$prefix"
	assert_contains "$PROJECT_ROOT/scripts/sessionizer --mark 1" "$prefix"
	assert_contains "$PROJECT_ROOT/scripts/sessionizer --mark 2" "$prefix"
	assert_contains "$PROJECT_ROOT/scripts/sessionizer --mark 3" "$prefix"
	assert_contains "ai-jump" "$prefix"
}

test_mark4_semicolon_key_is_escaped() {
	test_env_setup
	tmux run-shell "$PROJECT_ROOT/tmux-giant-steps.tmux"
	line=$(tmux list-keys -T prefix | grep -F -- '--mark 4')
	assert_contains '\;' "$line"
}

test_mark4_semicolon_key_is_escaped_when_set_explicitly() {
	test_env_setup
	# tmux unescapes "\;" down to a bare ";" when storing an @option, so
	# show-option hands the script back a single character -- this
	# reproduces that round trip instead of relying on the script's own
	# already-escaped default.
	tmux set-option -g @sessionizer-mark4-key "\;"
	tmux run-shell "$PROJECT_ROOT/tmux-giant-steps.tmux"
	line=$(tmux list-keys -T prefix | grep -F -- '--mark 4')
	assert_contains '\;' "$line"
}

test_custom_find_key_overrides_default() {
	test_env_setup
	tmux set-option -g @sessionizer-find-key "g"
	tmux run-shell "$PROJECT_ROOT/tmux-giant-steps.tmux"
	prefix=$(tmux list-keys -T prefix)
	assert_contains "$(session_binding prefix g)" "$prefix"
	assert_not_contains "sessionizer" "$(session_binding prefix f)"
}

test_prefix_key_is_configurable() {
	test_env_setup
	tmux set-option -g @sessionizer-prefix-key "M-x"
	tmux run-shell "$PROJECT_ROOT/tmux-giant-steps.tmux"
	assert_contains "M-x" "$(tmux list-keys -T root)"
}

test_popup_mode_off_uses_new_window() {
	test_env_setup
	tmux set-option -g @sessionizer-popup-mode off
	tmux run-shell "$PROJECT_ROOT/tmux-giant-steps.tmux"
	line=$(session_binding prefix f)
	assert_contains "neww" "$line"
	assert_not_contains "display-popup" "$line"
}

test_popup_mode_on_uses_display_popup_with_custom_size() {
	test_env_setup
	tmux set-option -g @sessionizer-popup-mode on
	tmux set-option -g @sessionizer-popup-width 70%
	tmux set-option -g @sessionizer-popup-height 60%
	tmux run-shell "$PROJECT_ROOT/tmux-giant-steps.tmux"
	line=$(session_binding prefix f)
	assert_contains "display-popup" "$line"
	assert_contains "70%" "$line"
	assert_contains "60%" "$line"
}

test_popup_mode_auto_matches_installed_tmux_capability() {
	test_env_setup
	tmux run-shell "$PROJECT_ROOT/tmux-giant-steps.tmux"
	line=$(session_binding prefix f)
	ver=$(tmux -V | grep -oE '[0-9]+\.[0-9]+' | head -1)
	supports=$(awk -v v="$ver" 'BEGIN { split(v, a, "."); print (a[1] > 3 || (a[1] == 3 && a[2] >= 2)) ? "1" : "0" }')
	if [ "$supports" = "1" ]; then
		assert_contains "display-popup" "$line"
	else
		assert_contains "neww" "$line"
	fi
}

test_ai_jump_popup_mode_off_uses_new_window() {
	test_env_setup
	tmux set-option -g @sessionizer-popup-mode off
	tmux run-shell "$PROJECT_ROOT/tmux-giant-steps.tmux"
	line=$(session_binding prefix Tab)
	assert_contains "neww" "$line"
	assert_not_contains "display-popup" "$line"
}

test_ai_jump_popup_mode_on_uses_display_popup() {
	test_env_setup
	tmux set-option -g @sessionizer-popup-mode on
	tmux run-shell "$PROJECT_ROOT/tmux-giant-steps.tmux"
	line=$(session_binding prefix Tab)
	assert_contains "display-popup" "$line"
}
