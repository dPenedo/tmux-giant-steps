#!/usr/bin/env bash
# TPM bootstrap: registers the "sessions" key-table and the
# sessionizer/marks/ai-jump binds. Every key is configurable via @option in
# .tmux.conf; the defaults match the original setup.
set -euo pipefail

CURRENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$CURRENT_DIR/scripts"

tmux_option() {
  local val
  val=$(tmux show-option -gqv "$1" 2>/dev/null)
  [ -n "$val" ] && echo "$val" || echo "$2"
}

# tmux unescapes "\;" down to a bare ";" when a user's .tmux.conf sets an
# @option to it, so show-option hands it back as a single character. A bare
# ";" passed as a bind-key argument is then parsed as tmux's own command
# separator instead of a literal key, so it has to be re-escaped here.
escape_semicolon() {
  case "$1" in
  ";") printf '\\;' ;;
  *) printf '%s' "$1" ;;
  esac
}

prefix_key=$(escape_semicolon "$(tmux_option "@sessionizer-prefix-key" "")")
find_key=$(escape_semicolon "$(tmux_option "@sessionizer-find-key" "f")")
edit_key=$(escape_semicolon "$(tmux_option "@sessionizer-edit-key" "e")")
add_key=$(escape_semicolon "$(tmux_option "@sessionizer-add-key" "a")")
mark1_key=$(escape_semicolon "$(tmux_option "@sessionizer-mark1-key" "j")")
mark2_key=$(escape_semicolon "$(tmux_option "@sessionizer-mark2-key" "k")")
mark3_key=$(escape_semicolon "$(tmux_option "@sessionizer-mark3-key" "l")")
mark4_key=$(escape_semicolon "$(tmux_option "@sessionizer-mark4-key" "\\;")")
ai_jump_key=$(escape_semicolon "$(tmux_option "@ai-jump-key" "Tab")")

# Main picker: opens in a new window by default (closes itself on exit); on
# tmux >= 3.2 it can open in a popup instead (@sessionizer-popup-mode).
popup_mode=$(tmux_option "@sessionizer-popup-mode" "auto")
popup_width=$(tmux_option "@sessionizer-popup-width" "85%")
popup_height=$(tmux_option "@sessionizer-popup-height" "85%")

# display-popup landed in tmux 3.2; parses "tmux 3.3a" / "tmux next-3.4" by
# taking the first M.N in `tmux -V`.
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

# By default (no @sessionizer-prefix-key) binds hang directly off tmux's own
# "prefix" table, matching most tmux plugins (tmux-resurrect, tmux-yank,
# tmux-grip...). Setting @sessionizer-prefix-key switches to a secondary
# "sessions" key-table instead.
if [ -n "$prefix_key" ]; then
  tmux bind-key -n "$prefix_key" switch-client -T sessions
  bind_table=(-T sessions)
else
  bind_table=()
fi

if [ "$use_popup" = 1 ]; then
  tmux bind-key "${bind_table[@]}" "$find_key" display-popup -w"$popup_width" -h"$popup_height" -E "$SCRIPTS/sessionizer"
else
  tmux bind-key "${bind_table[@]}" "$find_key" run-shell "tmux neww '$SCRIPTS/sessionizer'"
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

# Jump to panes running @ai-jump-pattern (default: claude|opencode).
# No -n: this is prefix+Tab, not a root-table key.
# ai-jump sorts the pane you came from last; in a popup it works that out on
# its own, but `neww` makes its own pane the active one first, so the origin
# has to be passed in (run-shell expands #{pane_id}, display-popup wouldn't).
if [ "$use_popup" = 1 ]; then
  tmux bind-key "$ai_jump_key" display-popup -w80% -h80% -E "$SCRIPTS/ai-jump"
else
  tmux bind-key "$ai_jump_key" run-shell "tmux neww '$SCRIPTS/ai-jump --from #{pane_id}'"
fi
