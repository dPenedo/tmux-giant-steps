# Tmux Giant Steps

A tmux plugin for jumping between projects, branches and running processes.

Four tools that share one config:

1. **Sessionizer**: an fzf picker over your tmux sessions and project directories, with a live preview of each session's windows. Inspired by [tmux-sessionizer](https://github.com/theprimeagen/tmux-sessionizer).
2. **Marks**: pin up to 4 directories to keys for one-keystroke jumps, and edit the list as plain text in Neovim. Inspired by [harpoon](https://github.com/theprimeagen/harpoon).
3. **Worktrees**: part of the sessionizer. Each git checkout shows its branch, worktrees are listed under their repo, `Ctrl-t` creates one and jumps there, and `prefix f w` switches between the worktrees of the repo you're in.
4. **ai-jump**: jump to the pane running some process (Claude Code and OpenCode by default, anything matching a regex really), with a live preview of the pane. It finds the process even inside a nested terminal like Neovim's `:terminal`, and shows the repo and branch of each pane, which helps when several agents run in worktrees of the same repo.

## Requirements

- [fzf](https://github.com/junegunn/fzf)
- tmux 3.2 or newer for popups; older versions open a new window instead
- git, for the worktree features
- Neovim, to edit marks

## Installation

With [TPM](https://github.com/tmux-plugins/tpm), add this to `~/.tmux.conf` and press `prefix I`:

```tmux
set -g @plugin 'dPenedo/tmux-giant-steps'
```

Without TPM, clone the repo and add:

```tmux
run-shell ~/path/to/tmux-giant-steps/tmux-giant-steps.tmux
```

## Keys

Everything except ai-jump lives behind `prefix f`:

| Key | Action |
| --- | --- |
| `prefix f f` | session/directory picker |
| `prefix f w` | worktrees of the current repo |
| `prefix f e` | edit marks (`Enter` on a line jumps to it) |
| `prefix f a` | add the current directory as a mark |
| `prefix f j` / `k` / `l` / `;` | jump to mark 1 / 2 / 3 / 4 |
| `prefix Tab` | ai-jump |

This way the plugin only takes two keys from tmux's prefix table (`f`, which was `find-window`, and `Tab`) instead of overriding your own binds. If you want them flat (`prefix j`, `prefix e`...), set `@sessionizer-prefix-key ""`.

`prefix f` opens a key table called `sessions`, so you can add your own binds to it, or reach it without the prefix:

```tmux
bind -T sessions p switch-client -l
bind -n M-s switch-client -T sessions
```

Inside the picker:

- `Enter`: go to the session, creating it if needed
- `Ctrl-x`: kill the session
- `Ctrl-t`: new worktree
- `Ctrl-Alt-d`: remove a worktree

When the picker creates a session for a directory that has a `.tmux-sessionizer` file, it sources it in the new session (or `~/.tmux-sessionizer` if the directory has none). Handy for activating a virtualenv, opening the editor, etc.

## Worktrees

`Ctrl-t` on a repo (or on one of its worktrees) asks for a branch and creates the worktree next to the repo as `<repo>-<branch>`, using the last part of the branch name: `feat/login` in `myrepo` becomes `myrepo-login`. You can change the directory before confirming. If the branch exists, locally or on a remote, it's checked out; otherwise it's created from the repo's `HEAD`.

Files that git doesn't track, like `.env` or `node_modules`, can be copied or symlinked into new worktrees with `@sessionizer-worktree-copy` and `@sessionizer-worktree-symlink`.

`Ctrl-Alt-d` removes a worktree and its session after asking. It never forces anything: if there are uncommitted changes, git refuses. If the branch is already merged, it also offers to delete it; an unmerged branch is always kept.

## Configuration

These are the defaults; set any of them in `~/.tmux.conf` before loading the plugin.

```tmux
# Where to look for projects. ":N" sets the depth for one entry.
set -g @sessionizer-search-path "~/repos"
set -g @sessionizer-extra-path ""          # extra directories, added as they are
set -g @sessionizer-max-depth "1"

set -g @sessionizer-prefix-key "f"         # "" for flat binds
set -g @sessionizer-find-key "f"
set -g @sessionizer-worktrees-key "w"
set -g @sessionizer-edit-key "e"
set -g @sessionizer-add-key "a"
set -g @sessionizer-mark1-key "j"
set -g @sessionizer-mark2-key "k"
set -g @sessionizer-mark3-key "l"
set -g @sessionizer-mark4-key "\;"         # ";" has to be escaped in tmux

# Copied or symlinked from the repo into each new worktree, comma-separated
set -g @sessionizer-worktree-copy ""       # e.g. ".env"
set -g @sessionizer-worktree-symlink ""    # e.g. "node_modules"

set -g @sessionizer-popup-mode "auto"      # on, off, or auto (popup if tmux supports it)
set -g @sessionizer-popup-width "85%"
set -g @sessionizer-popup-height "85%"

set -g @ai-jump-key "Tab"
set -g @ai-jump-pattern "claude|opencode"  # any regex, e.g. "vite|jest --watch|psql"
set -g @ai-jump-state-option ""
set -g @ai-jump-state-colors "waiting=1,done=2,working=3"
```

`@ai-jump-state-option` is the name of a pane or window option that holds a state for each pane, for example `@agent_state` set from Claude Code hooks with `tmux set -w -t "$TMUX_PANE" @agent_state waiting`. When it's set, ai-jump colors the panes by state and sorts them in the order of `@ai-jump-state-colors`, where each color is an ANSI color number (0-255).

Marks are stored in `~/.config/tmux-giant-steps/marks.conf` (or under `$XDG_CONFIG_HOME`), one path per line.
