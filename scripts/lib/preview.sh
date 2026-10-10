#!/bin/sh
# render_pane <pane-id> [lines]: a pane's content ready for an fzf preview.
# -J undoes tmux's own wrapping so fzf doesn't wrap it twice, and the awk
# strips the trailing spaces and color codes TUI apps pad lines with, which
# break the wrapping the same way.
render_pane() {
	pane_id="$1"
	lines="${2:-200}"
	tmux capture-pane -peJ -S "-$lines" -t "$pane_id" | awk '
		BEGIN { ESC = sprintf("%c", 27); pat = ESC "\\[[0-9;]*m$" }
		{
			line = $0
			while (1) {
				if (match(line, /[ \t]+$/)) { line = substr(line, 1, RSTART - 1); continue }
				if (match(line, pat))       { line = substr(line, 1, RSTART - 1); continue }
				break
			}
			print line
		}
	'
}
