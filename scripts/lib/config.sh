#!/bin/sh
# Shared config: XDG dirs, marks.conf path, tmux @options with their
# defaults. Sourced by the other scripts, not run directly.

PLUGIN_NAME="tmux-giant-steps"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$PLUGIN_NAME"
MARKS_FILE="$CONFIG_DIR/marks.conf"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/$PLUGIN_NAME"
PENDING_FILE="$CACHE_DIR/pending" # used by sessionizer --edit (see edit_marks)

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
	# Manual expansion: these values (tmux @options, marks.conf lines) are
	# literal strings that never go through an interactive shell, so a bare
	# "~" wouldn't expand on its own.
	"~/"*) printf '%s' "$HOME/${1#\~/}" ;;
	"~") printf '%s' "$HOME" ;;
	*) printf '%s' "$1" ;;
	esac
}
