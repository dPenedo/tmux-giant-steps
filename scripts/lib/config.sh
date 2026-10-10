#!/bin/sh
# Paths and tmux options shared by the scripts.

PLUGIN_NAME="tmux-giant-steps"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$PLUGIN_NAME"
MARKS_FILE="$CONFIG_DIR/marks.conf"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/$PLUGIN_NAME"
# shellcheck disable=SC2034 # used by sessionizer --edit (see edit_marks)
PENDING_FILE="$CACHE_DIR/pending"

tmux_option() {
	# tmux_option <@name> <default>
	val=$(tmux show-option -gqv "$1" 2>/dev/null)
	[ -n "$val" ] && printf '%s' "$val" || printf '%s' "$2"
}

ensure_config_dir() {
	mkdir -p "$CONFIG_DIR"
	[ -f "$MARKS_FILE" ] || : >"$MARKS_FILE"
}

expand_home() {
	case "$1" in
	# tmux options and marks.conf lines never go through a shell, so nothing
	# expands "~" for us.
	\~/*) printf '%s' "$HOME/${1#\~/}" ;;
	"~") printf '%s' "$HOME" ;;
	*) printf '%s' "$1" ;;
	esac
}
