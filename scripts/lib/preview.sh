#!/bin/sh
# render_pane <pane-id> [lines]: capture a pane and prep it for an fzf
# preview. -J rejoins lines tmux wrapped at the pane's original width
# (usually wider than the preview column); without it, fzf re-wraps
# already-wrapped lines and the preview looks staircased. The awk pass
# strips trailing whitespace/SGR codes (\e[...m) that TUI apps pad each
# line with to paint the background — left in, they break the re-wrap the
# same way.
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
