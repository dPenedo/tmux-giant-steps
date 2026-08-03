#!/bin/sh
# Unit tests for scripts/lib/config.sh: sourced directly, without going
# through the sessionizer/ai-jump CLI.

test_expand_home_tilde_slash() {
	. "$PROJECT_ROOT/scripts/lib/config.sh"
	HOME=/home/testuser
	assert_eq "/home/testuser/foo/bar" "$(expand_home '~/foo/bar')"
}

test_expand_home_bare_tilde() {
	. "$PROJECT_ROOT/scripts/lib/config.sh"
	HOME=/home/testuser
	assert_eq "/home/testuser" "$(expand_home '~')"
}

test_expand_home_absolute_path_untouched() {
	. "$PROJECT_ROOT/scripts/lib/config.sh"
	assert_eq "/opt/foo" "$(expand_home '/opt/foo')"
}

test_expand_home_relative_path_untouched() {
	. "$PROJECT_ROOT/scripts/lib/config.sh"
	assert_eq "repo" "$(expand_home 'repo')"
}

test_expand_home_does_not_touch_tilde_mid_string() {
	. "$PROJECT_ROOT/scripts/lib/config.sh"
	assert_eq "foo~bar" "$(expand_home 'foo~bar')"
}

test_tmux_option_returns_default_when_unset() {
	test_env_setup
	. "$PROJECT_ROOT/scripts/lib/config.sh"
	assert_eq "fallback" "$(tmux_option '@no-such-opt' 'fallback')"
}

test_tmux_option_returns_configured_value() {
	test_env_setup
	. "$PROJECT_ROOT/scripts/lib/config.sh"
	tmux set-option -g @sessionizer-test-opt "custom"
	assert_eq "custom" "$(tmux_option '@sessionizer-test-opt' 'fallback')"
}

test_ensure_config_dir_creates_dir_and_empty_marks_file() {
	test_env_setup
	. "$PROJECT_ROOT/scripts/lib/config.sh"
	ensure_config_dir
	[ -d "$CONFIG_DIR" ] || fail "CONFIG_DIR was not created: $CONFIG_DIR"
	[ -f "$MARKS_FILE" ] || fail "MARKS_FILE was not created: $MARKS_FILE"
	assert_eq "" "$(cat "$MARKS_FILE")"
}

test_ensure_config_dir_does_not_clobber_existing_marks() {
	test_env_setup
	. "$PROJECT_ROOT/scripts/lib/config.sh"
	ensure_config_dir
	printf 'ya-habia-algo\n' >"$MARKS_FILE"
	ensure_config_dir
	assert_eq "ya-habia-algo" "$(cat "$MARKS_FILE")"
}

test_config_dir_respects_xdg_config_home() {
	test_env_setup
	. "$PROJECT_ROOT/scripts/lib/config.sh"
	assert_eq "$XDG_CONFIG_HOME/tmux-giant-steps" "$CONFIG_DIR"
}

test_cache_dir_respects_xdg_cache_home() {
	test_env_setup
	. "$PROJECT_ROOT/scripts/lib/config.sh"
	assert_eq "$XDG_CACHE_HOME/tmux-giant-steps" "$CACHE_DIR"
}
