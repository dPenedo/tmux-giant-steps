#!/usr/bin/env bash
# TPM entry point: sets up the key bindings.
set -euo pipefail

CURRENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$CURRENT_DIR/scripts"

tmux_option() {
	local val
	val=$(tmux show-option -gqv "$1" 2>/dev/null)
	[ -n "$val" ] || val="$2"
	# A bare ";" is a command separator for bind-key.
	[ "$val" = ";" ] && val='\;'
	printf '%s\n' "$val"
}

# "" means flat binds, and show-option -gqv can't tell "" from unset.
if tmux show-options -g @sessionizer-prefix-key >/dev/null 2>&1; then
	prefix_key=$(tmux show-option -gqv @sessionizer-prefix-key)
else
	prefix_key="f"
fi

find_key=$(tmux_option "@sessionizer-find-key" "f")
edit_key=$(tmux_option "@sessionizer-edit-key" "e")
add_key=$(tmux_option "@sessionizer-add-key" "a")
worktrees_key=$(tmux_option "@sessionizer-worktrees-key" "w")
mark1_key=$(tmux_option "@sessionizer-mark1-key" "j")
mark2_key=$(tmux_option "@sessionizer-mark2-key" "k")
mark3_key=$(tmux_option "@sessionizer-mark3-key" "l")
mark4_key=$(tmux_option "@sessionizer-mark4-key" ";")
ai_jump_key=$(tmux_option "@ai-jump-key" "Tab")

# Popups need tmux 3.2; otherwise the pickers open in a new window.
popup_mode=$(tmux_option "@sessionizer-popup-mode" "auto")
popup_width=$(tmux_option "@sessionizer-popup-width" "85%")
popup_height=$(tmux_option "@sessionizer-popup-height" "85%")

# Handles versions like "tmux 3.3a" and "tmux next-3.4".
tmux_supports_popup() {
	local ver
	ver=$(tmux -V | grep -oE '[0-9]+\.[0-9]+' | head -1)
	[ -z "$ver" ] && return 1
	awk -v v="$ver" 'BEGIN { split(v, a, "."); exit !(a[1] > 3 || (a[1] == 3 && a[2] >= 2)) }'
}

use_popup=0
case "$popup_mode" in
on) use_popup=1 ;;
off) use_popup=0 ;;
*) tmux_supports_popup && use_popup=1 ;;
esac

# prefix f opens the "sessions" table, so the plugin takes one key from the
# prefix table instead of eight (TPM runs last and would override the
# user's own binds).
if [ -n "$prefix_key" ]; then
	tmux bind-key "$prefix_key" switch-client -T sessions
	bind_table=(-T sessions)
else
	bind_table=()
fi

if [ "$use_popup" = 1 ]; then
	tmux bind-key "${bind_table[@]}" "$find_key" display-popup -w"$popup_width" -h"$popup_height" -E "$SCRIPTS/sessionizer"
else
	tmux bind-key "${bind_table[@]}" "$find_key" run-shell "tmux neww '$SCRIPTS/sessionizer'"
fi

# display-popup doesn't expand #{...}, so the script asks tmux for the path.
if [ "$use_popup" = 1 ]; then
	tmux bind-key "${bind_table[@]}" "$worktrees_key" display-popup -w"$popup_width" -h"$popup_height" -E "$SCRIPTS/sessionizer --worktrees"
else
	tmux bind-key "${bind_table[@]}" "$worktrees_key" run-shell "tmux neww -c '#{pane_current_path}' '$SCRIPTS/sessionizer --worktrees'"
fi

# Marks (harpoon)
if [ "$use_popup" = 1 ]; then
	tmux bind-key "${bind_table[@]}" "$edit_key" display-popup -w60% -h40% -E "$SCRIPTS/sessionizer --edit"
else
	tmux bind-key "${bind_table[@]}" "$edit_key" run-shell "tmux neww '$SCRIPTS/sessionizer --edit'"
fi
tmux bind-key "${bind_table[@]}" "$add_key" run-shell "$SCRIPTS/sessionizer --add '#{pane_current_path}'"
tmux bind-key "${bind_table[@]}" "$mark1_key" run-shell "$SCRIPTS/sessionizer --mark 1"
tmux bind-key "${bind_table[@]}" "$mark2_key" run-shell "$SCRIPTS/sessionizer --mark 2"
tmux bind-key "${bind_table[@]}" "$mark3_key" run-shell "$SCRIPTS/sessionizer --mark 3"
tmux bind-key "${bind_table[@]}" "$mark4_key" run-shell "$SCRIPTS/sessionizer --mark 4"

# ai-jump stays on prefix Tab, outside the sessions table. With neww the new
# pane becomes the active one, so the origin pane is passed explicitly.
if [ "$use_popup" = 1 ]; then
	tmux bind-key "$ai_jump_key" display-popup -w80% -h80% -E "$SCRIPTS/ai-jump"
else
	tmux bind-key "$ai_jump_key" run-shell "tmux neww '$SCRIPTS/ai-jump --from #{pane_id}'"
fi
