# Tmux Giant Steps

A tmux plugin to step fast into different contexts: sessions, directories, processes.

Three navigation tools under one config surface, each a different way to
step in: a fuzzy directory/session switcher (ala [tmux-sessionizer](https://github.com/theprimeagen/tmux-sessionizer)),
Harpoon-style persistent marks on top of it (ala [harpoon](https://github.com/theprimeagen/harpoon)),
and a "jump to the pane running X" picker, great for AI CLI tools thanks to its live pane preview.

1. **Sessionizer**: fzf switcher for tmux sessions and directories, with a
   live preview of each session's panes and a kill-session mode (`Ctrl-x`).
2. **Harpoon-like marks**: pin up to 4 directories/sessions to a number for
   instant jumps, and edit the list as plain text with Neovim.
3. **ai-jump**: fuzzy-jump to any pane running a given process, matched by an
   `egrep` pattern (Claude Code and OpenCode by default, but any process
   works). It walks the full process tree, so it also finds processes
   running inside a nested terminal (e.g. Neovim's `:terminal`), not just
   the pane's own command. Its live preview makes it especially handy for
   jumping straight to the AI CLI that's mid-answer.

## Requirements

- [fzf](https://github.com/junegunn/fzf)
- tmux >= 3.2, optional and only needed for popup mode. Without it everything
  still works, opening in a plain new window instead.
- Neovim, only needed for editing marks (`prefix e`)

## Installation

### With [TPM](https://github.com/tmux-plugins/tpm) (recommended)

Add this to `~/.tmux.conf`:

```tmux
set -g @plugin 'dPenedo/tmux-giant-steps'

run '~/.tmux/plugins/tpm/tpm'
```

Then press `prefix + I` to fetch and load it.

### Manual

Clone this repo and source it from `~/.tmux.conf`:

```tmux
run-shell ~/path/to/tmux-giant-steps/tmux-giant-steps.tmux
```

## Usage / default key bindings

By default every bind hangs directly off tmux's own `prefix`, one hop, same
as most tmux plugins.

| Key | Action |
| --- | --- |
| `prefix f` | open the session/directory picker |
| `prefix e` | edit marks (`Enter` on a line jumps to it) |
| `prefix a` | add the current pane's directory as a mark |
| `prefix j` / `k` / `l` / `;` | jump to mark 1 / 2 / 3 / 4 |
| `prefix Tab` | jump to a pane matching `@ai-jump-pattern` |

Set `@sessionizer-prefix-key` (e.g. `"M-s"`) to opt into a secondary
`sessions` key-table instead, entered with that key and holding all the
sub-binds above without needing tmux's `prefix` first.

Inside the picker: `Enter` jumps/creates the session, `Ctrl-x` kills the
selected session.

## Configuration

Set any of these as tmux `@options` in `~/.tmux.conf`, before the `run` line:

```tmux
set -g @sessionizer-search-path "~/repos"
set -g @sessionizer-extra-path "~/work,~/.config/nvim"
set -g @sessionizer-max-depth "1"

set -g @sessionizer-prefix-key ""        # e.g. "M-s" for a secondary key-table
set -g @sessionizer-find-key "f"
set -g @sessionizer-edit-key "e"
set -g @sessionizer-add-key "a"
set -g @sessionizer-mark1-key "j"
set -g @sessionizer-mark2-key "k"
set -g @sessionizer-mark3-key "l"
set -g @sessionizer-mark4-key "\;"

set -g @sessionizer-popup-mode "auto"    # on | off | auto
set -g @sessionizer-popup-width "85%"
set -g @sessionizer-popup-height "85%"

set -g @ai-jump-key "Tab"
set -g @ai-jump-pattern "claude|opencode"     # or e.g. "vite|jest --watch|psql"
```

| Option | Default | Description |
| --- | --- | --- |
| `@sessionizer-search-path` | `~/repos` | Comma-separated roots to search for directories. Append `:N` to an entry to override its depth, e.g. `~/repos:2`. |
| `@sessionizer-extra-path` | *(empty)* | Comma-separated extra paths, added as-is regardless of depth. |
| `@sessionizer-max-depth` | `1` | Default search depth for `@sessionizer-search-path` entries. |
| `@sessionizer-prefix-key` | *(empty)* | If set (e.g. `M-s`), binds move off tmux's `prefix` onto a secondary `sessions` key-table entered with this key instead. |
| `@sessionizer-find-key` | `f` | Opens the fuzzy picker. |
| `@sessionizer-edit-key` | `e` | Edits `marks.conf` in Neovim. |
| `@sessionizer-add-key` | `a` | Adds the current pane's directory as a new mark. |
| `@sessionizer-mark1-key` … `@sessionizer-mark4-key` | `j` `k` `l` `\;` | Jump straight to mark *N*. Note `;` must be escaped as `\;`, tmux's own command separator. |
| `@sessionizer-popup-mode` | `auto` | `on` always uses `display-popup`, `off` always opens a new window, `auto` picks based on the installed tmux version. |
| `@sessionizer-popup-width` / `@sessionizer-popup-height` | `85%` | Size of the picker's popup (only applies in popup mode). |
| `@ai-jump-key` | `Tab` | Key bound on `prefix` (not a root key) that runs the picker. |
| `@ai-jump-pattern` | `claude\|opencode` | `egrep` pattern matched against running processes. Not limited to AI CLIs, e.g. `"vite\|jest --watch\|psql"` works to jump to dev servers, test watchers, or DB clients. |

Marks aren't a tmux `@option`: they're a plain text file at
`$XDG_CONFIG_HOME/tmux-giant-steps/marks.conf` (defaults to
`~/.config/tmux-giant-steps/marks.conf`), one path per line, edited directly
through `prefix e`.
