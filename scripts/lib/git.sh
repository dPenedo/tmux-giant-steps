#!/bin/sh
# Git worktree helpers shared by sessionizer and ai-jump. Sourced, not run.
#
# Everything except repo_main reads .git / HEAD directly instead of calling
# git: sessionizer --list runs them once per directory under the search path,
# and a fork+exec of git each time is what would make the picker slow to open.

WT_ARROW=$(printf '\342\206\220') # "←", built once rather than per directory

# worktree_read <dir>: sets wt_kind / wt_main / wt_branch / wt_label if <dir>
# is itself the top of a git checkout, returns 1 otherwise. wt_kind is "main"
# for the repo's own checkout and "linked" for a `git worktree add` one, whose
# main is the checkout its .git file points back into. wt_branch is "detached"
# when HEAD isn't a branch. wt_label is what the pickers show next to it:
# "[main]", or "[feat/x] ← repo" for a linked worktree of "repo".
worktree_read() {
	wt_dir=${1%/}
	if [ -d "$wt_dir/.git" ]; then
		wt_kind=main
		wt_main=$wt_dir
		wt_gitdir=$wt_dir/.git
	elif [ -f "$wt_dir/.git" ]; then
		read -r wt_gitdir <"$wt_dir/.git" || return 1
		wt_gitdir=${wt_gitdir#gitdir: }
		# worktree.useRelativePaths writes it relative to the worktree.
		case "$wt_gitdir" in
		/*) ;;
		*) wt_gitdir=$(CDPATH= cd -- "$wt_dir/$wt_gitdir" 2>/dev/null && pwd -P) || return 1 ;;
		esac
		case "$wt_gitdir" in
		# A submodule's .git file points into .git/modules/ instead: not ours.
		*/worktrees/*) ;;
		*) return 1 ;;
		esac
		wt_kind=linked
		wt_main=${wt_gitdir%/worktrees/*}
		wt_main=${wt_main%/.git}
	else
		return 1
	fi
	read -r wt_head 2>/dev/null <"$wt_gitdir/HEAD" || return 1
	case "$wt_head" in
	"ref: refs/heads/"*) wt_branch=${wt_head#"ref: refs/heads/"} ;;
	*) wt_branch=detached ;;
	esac
	if [ "$wt_kind" = linked ]; then
		wt_label="[$wt_branch] $WT_ARROW ${wt_main##*/}"
	else
		wt_label="[$wt_branch]"
	fi
}

# find_worktree_root <dir>: the nearest ancestor-or-self of <dir> that is the
# top of a git checkout (for a pane or session sitting in a subdirectory).
find_worktree_root() {
	wt_root=${1%/}
	while [ -n "$wt_root" ]; do
		if [ -e "$wt_root/.git" ]; then
			printf '%s\n' "$wt_root"
			return 0
		fi
		wt_root=${wt_root%/*}
	done
	return 1
}

# worktree_dir_for_branch <main> <branch>: where a new worktree for <branch>
# goes: next to <main>, named "<main>-<last segment of branch>"
# (feat/eguneko-esaera -> ardiketak-eguneko-esaera).
worktree_dir_for_branch() {
	printf '%s/%s-%s\n' "$(dirname -- "$1")" "${1##*/}" "${2##*/}"
}

# repo_main <dir>: the main checkout of the repo <dir> belongs to, anywhere
# inside it. Asks git, so it's for one-off actions, not for listings.
repo_main() {
	wt_common=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
	case "$wt_common" in
	*/.git) printf '%s\n' "${wt_common%/.git}" ;;
	*) printf '%s\n' "$wt_common" ;; # bare repo
	esac
}
