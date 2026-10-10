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
  [ -n "$val" ] || val="$2"
  # tmux stores "\;" in an @option as a bare ";", and a bare ";" in a
  # bind-key argument is its own command separator, so hand it back escaped.
  [ "$val" = ";" ] && val='\;'
  printf '%s\n' "$val"
}

# Not via tmux_option: an @option set to "" reads back exactly like an unset
# one through `show-option -gqv`, and "" is a meaningful value here -- it's how
# you ask for flat binds with no key-table at all. `show-options -g <name>`
# does tell the two apart (it fails outright when the option was never set).
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

# @sessionizer-prefix-key gives the sessionizer its own namespace: the key
# goes *after* tmux's prefix and only opens the "sessions" key-table, so its
# binds are three-key chords (prefix f f, prefix f j...). Default because a
# plugin claiming eight keys on the prefix table would silently outbid binds
# the user already has -- TPM runs last, so the plugin always wins, with no
# warning. This way it claims one key, and only clobbers `find-window`.
#
# Set it to "" for flat binds on tmux's own prefix instead. It is never a
# root-table key -- a bare "f" as one would eat the key everywhere; for a
# no-prefix entry point, add your own `bind -n M-s switch-client -T sessions`.
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

# Worktrees of the current pane's repo. No path argument in either branch:
# display-popup wouldn't expand #{pane_current_path}, so the script asks tmux
# for it, and in a `neww` the new pane starts there (-c) and is the active one.
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

# Jump to panes running @ai-jump-pattern (default: claude|opencode).
#
# Deliberately NOT in $bind_table: @sessionizer-prefix-key namespaces the
# sessionizer and its marks, and ai-jump is neither -- it's a separate tool
# that happens to ship here, reached often enough that a three-key chord for
# it is a downgrade. So it stays on prefix+Tab either way. Never a root key.
#
# ai-jump sorts the pane you came from last; in a popup it works that out on
# its own, but `neww` makes its own pane the active one first, so the origin
# has to be passed in (run-shell expands #{pane_id}, display-popup wouldn't).
if [ "$use_popup" = 1 ]; then
  tmux bind-key "$ai_jump_key" display-popup -w80% -h80% -E "$SCRIPTS/ai-jump"
else
  tmux bind-key "$ai_jump_key" run-shell "tmux neww '$SCRIPTS/ai-jump --from #{pane_id}'"
fi
