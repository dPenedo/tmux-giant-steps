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
   the pane's own command. The pane you launched it from is sorted last
   (the sessionizer likewise hides the session you're already in). Its live
   preview makes it especially handy for jumping straight to the AI CLI
   that's mid-answer.

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

The sessionizer and its marks live behind `prefix f`, which opens a `sessions`
key-table; the next key picks the action. Only two keys are claimed on tmux's
own prefix.

| Key | Action |
| --- | --- |
| `prefix f` `f` | open the session/directory picker |
| `prefix f` `e` | edit marks (`Enter` on a line jumps to it) |
| `prefix f` `a` | add the current pane's directory as a mark |
| `prefix f` `j` / `k` / `l` / `;` | jump to mark 1 / 2 / 3 / 4 |
| `prefix Tab` | jump to a pane matching `@ai-jump-pattern` |

The extra hop is deliberate. A plugin binding eight keys straight onto the
prefix table would quietly outbid whatever you have there already — TPM runs
at the end of your config, so the plugin's binds win, and nothing warns you
that your `bind j select-pane -D` stopped working. Behind `prefix f` the only
tmux default it costs you is `find-window`.

If you'd rather have flat binds — `prefix f`, `prefix j`, `prefix e`… — set
`@sessionizer-prefix-key ""`. Then it does clobber `find-window`,
`last-window` (`l`) and `last-pane` (`;`), plus any of `e` `a` `j` `k` you had
bound. Or set it to another key to move the whole namespace.

`ai-jump` stays on `prefix Tab` either way: it's a separate tool from the
sessionizer and its marks, and reached often enough that a three-key chord
would be a downgrade.

The `sessions` key-table is a stable name you can hang your own binds off —
`bind -T sessions p switch-client -l` and the like. For an entry point that
skips tmux's prefix entirely, bind that yourself too:
`bind -n M-s switch-client -T sessions`.

Inside the picker: `Enter` jumps/creates the session, `Ctrl-x` kills the
selected session.

## Configuration

Set any of these as tmux `@options` in `~/.tmux.conf`, before the `run` line:

```tmux
set -g @sessionizer-search-path "~/repos"
set -g @sessionizer-extra-path "~/work,~/.config/nvim"
set -g @sessionizer-max-depth "1"

set -g @sessionizer-prefix-key "f"       # "" for flat binds on tmux's prefix
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
| `@sessionizer-prefix-key` | `f` | Key that opens the `sessions` key-table holding the sessionizer/marks binds, i.e. `prefix f <key>`. Always goes through tmux's prefix; see above for a root-table entry point. Set to `""` for flat binds and no key-table. Doesn't affect `@ai-jump-key`. |
| `@sessionizer-find-key` | `f` | Opens the fuzzy picker, inside the key-table (so `prefix f f` by default). |
| `@sessionizer-edit-key` | `e` | Edits `marks.conf` in Neovim. |
| `@sessionizer-add-key` | `a` | Adds the current pane's directory as a new mark. |
| `@sessionizer-mark1-key` … `@sessionizer-mark4-key` | `j` `k` `l` `\;` | Jump straight to mark *N*. Note `;` must be escaped as `\;`, tmux's own command separator. |
| `@sessionizer-popup-mode` | `auto` | `on` always uses `display-popup`, `off` always opens a new window, `auto` picks based on the installed tmux version. |
| `@sessionizer-popup-width` / `@sessionizer-popup-height` | `85%` | Size of the picker's popup (only applies in popup mode). |
| `@ai-jump-key` | `Tab` | Key that runs the pane picker, always on tmux's own `prefix` (never a root key, never in the `sessions` table). |
| `@ai-jump-pattern` | `claude\|opencode` | `egrep` pattern matched against running processes. Not limited to AI CLIs, e.g. `"vite\|jest --watch\|psql"` works to jump to dev servers, test watchers, or DB clients. |

Marks aren't a tmux `@option`: they're a plain text file at
`$XDG_CONFIG_HOME/tmux-giant-steps/marks.conf` (defaults to
`~/.config/tmux-giant-steps/marks.conf`), one path per line, edited directly
through `prefix e`.
